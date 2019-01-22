SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: que_validate_tags(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_validate_tags(tags_array jsonb) RETURNS boolean
    LANGUAGE sql
    AS $$
  SELECT bool_and(
    jsonb_typeof(value) = 'string'
    AND
    char_length(value::text) <= 100
  )
  FROM jsonb_array_elements(tags_array)
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: que_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.que_jobs (
    priority smallint DEFAULT 100 NOT NULL,
    run_at timestamp with time zone DEFAULT now() NOT NULL,
    id bigint NOT NULL,
    job_class text NOT NULL,
    error_count integer DEFAULT 0 NOT NULL,
    last_error_message text,
    queue text DEFAULT 'default'::text NOT NULL,
    last_error_backtrace text,
    finished_at timestamp with time zone,
    expired_at timestamp with time zone,
    args jsonb DEFAULT '[]'::jsonb NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT error_length CHECK (((char_length(last_error_message) <= 500) AND (char_length(last_error_backtrace) <= 10000))),
    CONSTRAINT job_class_length CHECK ((char_length(
CASE job_class
    WHEN 'ActiveJob::QueueAdapters::QueAdapter::JobWrapper'::text THEN ((args -> 0) ->> 'job_class'::text)
    ELSE job_class
END) <= 200)),
    CONSTRAINT queue_length CHECK ((char_length(queue) <= 100)),
    CONSTRAINT valid_args CHECK ((jsonb_typeof(args) = 'array'::text)),
    CONSTRAINT valid_data CHECK (((jsonb_typeof(data) = 'object'::text) AND ((NOT (data ? 'tags'::text)) OR ((jsonb_typeof((data -> 'tags'::text)) = 'array'::text) AND (jsonb_array_length((data -> 'tags'::text)) <= 5) AND public.que_validate_tags((data -> 'tags'::text))))))
)
WITH (fillfactor='90');


--
-- Name: TABLE que_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.que_jobs IS '4';


--
-- Name: que_determine_job_state(public.que_jobs); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_determine_job_state(job public.que_jobs) RETURNS text
    LANGUAGE sql
    AS $$
  SELECT
    CASE
    WHEN job.expired_at  IS NOT NULL    THEN 'expired'
    WHEN job.finished_at IS NOT NULL    THEN 'finished'
    WHEN job.error_count > 0            THEN 'errored'
    WHEN job.run_at > CURRENT_TIMESTAMP THEN 'scheduled'
    ELSE                                     'ready'
    END
$$;


--
-- Name: que_job_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_job_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    locker_pid integer;
    sort_key json;
  BEGIN
    -- Don't do anything if the job is scheduled for a future time.
    IF NEW.run_at IS NOT NULL AND NEW.run_at > now() THEN
      RETURN null;
    END IF;

    -- Pick a locker to notify of the job's insertion, weighted by their number
    -- of workers. Should bounce pseudorandomly between lockers on each
    -- invocation, hence the md5-ordering, but still touch each one equally,
    -- hence the modulo using the job_id.
    SELECT pid
    INTO locker_pid
    FROM (
      SELECT *, last_value(row_number) OVER () + 1 AS count
      FROM (
        SELECT *, row_number() OVER () - 1 AS row_number
        FROM (
          SELECT *
          FROM public.que_lockers ql, generate_series(1, ql.worker_count) AS id
          WHERE listening AND queues @> ARRAY[NEW.queue]
          ORDER BY md5(pid::text || id::text)
        ) t1
      ) t2
    ) t3
    WHERE NEW.id % count = row_number;

    IF locker_pid IS NOT NULL THEN
      -- There's a size limit to what can be broadcast via LISTEN/NOTIFY, so
      -- rather than throw errors when someone enqueues a big job, just
      -- broadcast the most pertinent information, and let the locker query for
      -- the record after it's taken the lock. The worker will have to hit the
      -- DB in order to make sure the job is still visible anyway.
      SELECT row_to_json(t)
      INTO sort_key
      FROM (
        SELECT
          'job_available' AS message_type,
          NEW.queue       AS queue,
          NEW.priority    AS priority,
          NEW.id          AS id,
          -- Make sure we output timestamps as UTC ISO 8601
          to_char(NEW.run_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS run_at
      ) t;

      PERFORM pg_notify('que_listener_' || locker_pid::text, sort_key::text);
    END IF;

    RETURN null;
  END
$$;


--
-- Name: que_state_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.que_state_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE
    row record;
    message json;
    previous_state text;
    current_state text;
  BEGIN
    IF TG_OP = 'INSERT' THEN
      previous_state := 'nonexistent';
      current_state  := public.que_determine_job_state(NEW);
      row            := NEW;
    ELSIF TG_OP = 'DELETE' THEN
      previous_state := public.que_determine_job_state(OLD);
      current_state  := 'nonexistent';
      row            := OLD;
    ELSIF TG_OP = 'UPDATE' THEN
      previous_state := public.que_determine_job_state(OLD);
      current_state  := public.que_determine_job_state(NEW);

      -- If the state didn't change, short-circuit.
      IF previous_state = current_state THEN
        RETURN null;
      END IF;

      row := NEW;
    ELSE
      RAISE EXCEPTION 'Unrecognized TG_OP: %', TG_OP;
    END IF;

    SELECT row_to_json(t)
    INTO message
    FROM (
      SELECT
        'job_change' AS message_type,
        row.id       AS id,
        row.queue    AS queue,

        coalesce(row.data->'tags', '[]'::jsonb) AS tags,

        to_char(row.run_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS run_at,
        to_char(now()      AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS time,

        CASE row.job_class
        WHEN 'ActiveJob::QueueAdapters::QueAdapter::JobWrapper' THEN
          coalesce(
            row.args->0->>'job_class',
            'ActiveJob::QueueAdapters::QueAdapter::JobWrapper'
          )
        ELSE
          row.job_class
        END AS job_class,

        previous_state AS previous_state,
        current_state  AS current_state
    ) t;

    PERFORM pg_notify('que_state', message::text);

    RETURN null;
  END
$$;


--
-- Name: aker_process_module_pairings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aker_process_module_pairings (
    id integer NOT NULL,
    from_step_id integer,
    to_step_id integer,
    default_path boolean NOT NULL,
    aker_process_id integer
);


--
-- Name: aker_process_module_pairings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aker_process_module_pairings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aker_process_module_pairings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aker_process_module_pairings_id_seq OWNED BY public.aker_process_module_pairings.id;


--
-- Name: aker_process_modules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aker_process_modules (
    id integer NOT NULL,
    name character varying NOT NULL,
    aker_process_id integer,
    min_value integer,
    max_value integer
);


--
-- Name: aker_process_modules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aker_process_modules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aker_process_modules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aker_process_modules_id_seq OWNED BY public.aker_process_modules.id;


--
-- Name: aker_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aker_processes (
    id integer NOT NULL,
    name character varying NOT NULL,
    "TAT" integer,
    uuid uuid NOT NULL,
    process_class integer
);


--
-- Name: aker_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aker_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aker_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aker_processes_id_seq OWNED BY public.aker_processes.id;


--
-- Name: aker_product_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aker_product_processes (
    id integer NOT NULL,
    product_id integer,
    aker_process_id integer,
    stage integer NOT NULL
);


--
-- Name: aker_product_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aker_product_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aker_product_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aker_product_processes_id_seq OWNED BY public.aker_product_processes.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: catalogues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalogues (
    id integer NOT NULL,
    url character varying,
    lims_id public.citext NOT NULL,
    pipeline character varying,
    current boolean,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: catalogues_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.catalogues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: catalogues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.catalogues_id_seq OWNED BY public.catalogues.id;


--
-- Name: data_release_strategies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_release_strategies (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying,
    study_code character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jobs (
    id integer NOT NULL,
    container_uuid uuid,
    started timestamp without time zone,
    completed timestamp without time zone,
    cancelled timestamp without time zone,
    broken timestamp without time zone,
    work_order_id bigint NOT NULL,
    close_comment character varying,
    output_set_uuid uuid,
    uuid uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    input_set_uuid uuid,
    revised_output_set_uuid uuid,
    forwarded timestamp without time zone
);


--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jobs_id_seq OWNED BY public.jobs.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    permitted public.citext NOT NULL,
    accessible_type character varying NOT NULL,
    accessible_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    permission_type character varying NOT NULL
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: process_module_choices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.process_module_choices (
    id bigint NOT NULL,
    work_plan_id bigint NOT NULL,
    aker_process_id bigint NOT NULL,
    aker_process_module_id bigint NOT NULL,
    "position" integer NOT NULL,
    selected_value integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: process_module_choices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.process_module_choices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: process_module_choices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.process_module_choices_id_seq OWNED BY public.process_module_choices.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    catalogue_id integer,
    requested_biomaterial_type character varying,
    product_version integer,
    description character varying,
    availability boolean DEFAULT true NOT NULL,
    uuid uuid NOT NULL
);


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: que_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.que_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: que_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.que_jobs_id_seq OWNED BY public.que_jobs.id;


--
-- Name: que_lockers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.que_lockers (
    pid integer NOT NULL,
    worker_count integer NOT NULL,
    worker_priorities integer[] NOT NULL,
    ruby_pid integer NOT NULL,
    ruby_hostname text NOT NULL,
    queues text[] NOT NULL,
    listening boolean NOT NULL,
    CONSTRAINT valid_queues CHECK (((array_ndims(queues) = 1) AND (array_length(queues, 1) IS NOT NULL))),
    CONSTRAINT valid_worker_priorities CHECK (((array_ndims(worker_priorities) = 1) AND (array_length(worker_priorities, 1) IS NOT NULL)))
);


--
-- Name: que_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.que_values (
    key text NOT NULL,
    value jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT valid_value CHECK ((jsonb_typeof(value) = 'object'::text))
)
WITH (fillfactor='90');


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: work_order_module_choices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_order_module_choices (
    id integer NOT NULL,
    work_order_id integer,
    aker_process_modules_id integer,
    "position" integer,
    selected_value integer
);


--
-- Name: work_order_module_choices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.work_order_module_choices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: work_order_module_choices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.work_order_module_choices_id_seq OWNED BY public.work_order_module_choices.id;


--
-- Name: work_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_orders (
    id integer NOT NULL,
    status character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    total_cost numeric(8,2),
    cost_per_sample numeric(8,2),
    material_updated boolean DEFAULT false NOT NULL,
    order_index integer NOT NULL,
    dispatch_date timestamp without time zone,
    completion_date timestamp without time zone,
    set_uuid uuid,
    work_order_uuid uuid NOT NULL,
    work_plan_id bigint NOT NULL,
    process_id bigint NOT NULL
);


--
-- Name: work_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.work_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: work_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.work_orders_id_seq OWNED BY public.work_orders.id;


--
-- Name: work_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_plans (
    id integer NOT NULL,
    project_id integer,
    product_id bigint,
    original_set_uuid uuid,
    owner_email public.citext NOT NULL,
    comment character varying,
    uuid uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    cancelled timestamp without time zone,
    data_release_strategy_id uuid,
    priority character varying DEFAULT 'standard'::character varying NOT NULL,
    sent_queued_events boolean DEFAULT false NOT NULL,
    estimated_cost numeric(8,2)
);


--
-- Name: work_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.work_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: work_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.work_plans_id_seq OWNED BY public.work_plans.id;


--
-- Name: aker_process_module_pairings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_process_module_pairings ALTER COLUMN id SET DEFAULT nextval('public.aker_process_module_pairings_id_seq'::regclass);


--
-- Name: aker_process_modules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_process_modules ALTER COLUMN id SET DEFAULT nextval('public.aker_process_modules_id_seq'::regclass);


--
-- Name: aker_processes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_processes ALTER COLUMN id SET DEFAULT nextval('public.aker_processes_id_seq'::regclass);


--
-- Name: aker_product_processes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_product_processes ALTER COLUMN id SET DEFAULT nextval('public.aker_product_processes_id_seq'::regclass);


--
-- Name: catalogues id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogues ALTER COLUMN id SET DEFAULT nextval('public.catalogues_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs ALTER COLUMN id SET DEFAULT nextval('public.jobs_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: process_module_choices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.process_module_choices ALTER COLUMN id SET DEFAULT nextval('public.process_module_choices_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: que_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_jobs ALTER COLUMN id SET DEFAULT nextval('public.que_jobs_id_seq'::regclass);


--
-- Name: work_order_module_choices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_module_choices ALTER COLUMN id SET DEFAULT nextval('public.work_order_module_choices_id_seq'::regclass);


--
-- Name: work_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders ALTER COLUMN id SET DEFAULT nextval('public.work_orders_id_seq'::regclass);


--
-- Name: work_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_plans ALTER COLUMN id SET DEFAULT nextval('public.work_plans_id_seq'::regclass);


--
-- Name: aker_process_module_pairings aker_process_module_pairings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_process_module_pairings
    ADD CONSTRAINT aker_process_module_pairings_pkey PRIMARY KEY (id);


--
-- Name: aker_process_modules aker_process_modules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_process_modules
    ADD CONSTRAINT aker_process_modules_pkey PRIMARY KEY (id);


--
-- Name: aker_processes aker_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_processes
    ADD CONSTRAINT aker_processes_pkey PRIMARY KEY (id);


--
-- Name: aker_product_processes aker_product_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_product_processes
    ADD CONSTRAINT aker_product_processes_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: catalogues catalogues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogues
    ADD CONSTRAINT catalogues_pkey PRIMARY KEY (id);


--
-- Name: data_release_strategies data_release_strategies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_release_strategies
    ADD CONSTRAINT data_release_strategies_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: process_module_choices process_module_choices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.process_module_choices
    ADD CONSTRAINT process_module_choices_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: que_jobs que_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_jobs
    ADD CONSTRAINT que_jobs_pkey PRIMARY KEY (id);


--
-- Name: que_lockers que_lockers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_lockers
    ADD CONSTRAINT que_lockers_pkey PRIMARY KEY (pid);


--
-- Name: que_values que_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.que_values
    ADD CONSTRAINT que_values_pkey PRIMARY KEY (key);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: work_order_module_choices work_order_module_choices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_module_choices
    ADD CONSTRAINT work_order_module_choices_pkey PRIMARY KEY (id);


--
-- Name: work_orders work_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_pkey PRIMARY KEY (id);


--
-- Name: work_plans work_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_plans
    ADD CONSTRAINT work_plans_pkey PRIMARY KEY (id);


--
-- Name: index_aker_process_module_pairings_on_aker_process_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aker_process_module_pairings_on_aker_process_id ON public.aker_process_module_pairings USING btree (aker_process_id);


--
-- Name: index_aker_process_module_pairings_on_from_step_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aker_process_module_pairings_on_from_step_id ON public.aker_process_module_pairings USING btree (from_step_id);


--
-- Name: index_aker_process_module_pairings_on_to_step_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aker_process_module_pairings_on_to_step_id ON public.aker_process_module_pairings USING btree (to_step_id);


--
-- Name: index_aker_process_modules_on_aker_process_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aker_process_modules_on_aker_process_id ON public.aker_process_modules USING btree (aker_process_id);


--
-- Name: index_aker_process_modules_on_aker_process_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_aker_process_modules_on_aker_process_id_and_name ON public.aker_process_modules USING btree (aker_process_id, name);


--
-- Name: index_aker_product_processes_on_aker_process_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aker_product_processes_on_aker_process_id ON public.aker_product_processes USING btree (aker_process_id);


--
-- Name: index_aker_product_processes_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aker_product_processes_on_product_id ON public.aker_product_processes USING btree (product_id);


--
-- Name: index_catalogues_on_lims_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_catalogues_on_lims_id ON public.catalogues USING btree (lims_id);


--
-- Name: index_data_release_strategies_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_data_release_strategies_on_id ON public.data_release_strategies USING btree (id);


--
-- Name: index_jobs_on_work_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jobs_on_work_order_id ON public.jobs USING btree (work_order_id);


--
-- Name: index_on_aker_pairings; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_on_aker_pairings ON public.aker_process_module_pairings USING btree (from_step_id, to_step_id, aker_process_id);


--
-- Name: index_permissions_on_accessible_type_and_accessible_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_accessible_type_and_accessible_id ON public.permissions USING btree (accessible_type, accessible_id);


--
-- Name: index_permissions_on_permitted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_permissions_on_permitted ON public.permissions USING btree (permitted);


--
-- Name: index_permissions_on_various; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permissions_on_various ON public.permissions USING btree (permitted, permission_type, accessible_id, accessible_type);


--
-- Name: index_process_module_choices_on_aker_process_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_process_module_choices_on_aker_process_id ON public.process_module_choices USING btree (aker_process_id);


--
-- Name: index_process_module_choices_on_aker_process_module_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_process_module_choices_on_aker_process_module_id ON public.process_module_choices USING btree (aker_process_module_id);


--
-- Name: index_process_module_choices_on_work_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_process_module_choices_on_work_plan_id ON public.process_module_choices USING btree (work_plan_id);


--
-- Name: index_products_on_catalogue_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_on_catalogue_id ON public.products USING btree (catalogue_id);


--
-- Name: index_work_order_module_choices_on_aker_process_modules_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_work_order_module_choices_on_aker_process_modules_id ON public.work_order_module_choices USING btree (aker_process_modules_id);


--
-- Name: index_work_order_module_choices_on_work_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_work_order_module_choices_on_work_order_id ON public.work_order_module_choices USING btree (work_order_id);


--
-- Name: index_work_orders_on_process_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_work_orders_on_process_id ON public.work_orders USING btree (process_id);


--
-- Name: index_work_orders_on_work_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_work_orders_on_work_plan_id ON public.work_orders USING btree (work_plan_id);


--
-- Name: index_work_plans_on_data_release_strategy_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_work_plans_on_data_release_strategy_id ON public.work_plans USING btree (data_release_strategy_id);


--
-- Name: index_work_plans_on_owner_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_work_plans_on_owner_email ON public.work_plans USING btree (owner_email);


--
-- Name: index_work_plans_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_work_plans_on_product_id ON public.work_plans USING btree (product_id);


--
-- Name: que_jobs_args_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_jobs_args_gin_idx ON public.que_jobs USING gin (args jsonb_path_ops);


--
-- Name: que_jobs_data_gin_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_jobs_data_gin_idx ON public.que_jobs USING gin (data jsonb_path_ops);


--
-- Name: que_poll_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX que_poll_idx ON public.que_jobs USING btree (queue, priority, run_at, id) WHERE ((finished_at IS NULL) AND (expired_at IS NULL));


--
-- Name: que_jobs que_job_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER que_job_notify AFTER INSERT ON public.que_jobs FOR EACH ROW EXECUTE PROCEDURE public.que_job_notify();


--
-- Name: que_jobs que_state_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER que_state_notify AFTER INSERT OR DELETE OR UPDATE ON public.que_jobs FOR EACH ROW EXECUTE PROCEDURE public.que_state_notify();


--
-- Name: process_module_choices fk_rails_195798c85f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.process_module_choices
    ADD CONSTRAINT fk_rails_195798c85f FOREIGN KEY (aker_process_id) REFERENCES public.aker_processes(id);


--
-- Name: work_order_module_choices fk_rails_42b0ef90a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_module_choices
    ADD CONSTRAINT fk_rails_42b0ef90a2 FOREIGN KEY (work_order_id) REFERENCES public.work_orders(id);


--
-- Name: work_order_module_choices fk_rails_4568d52d49; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_module_choices
    ADD CONSTRAINT fk_rails_4568d52d49 FOREIGN KEY (aker_process_modules_id) REFERENCES public.aker_process_modules(id);


--
-- Name: process_module_choices fk_rails_4a4bc501a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.process_module_choices
    ADD CONSTRAINT fk_rails_4a4bc501a8 FOREIGN KEY (work_plan_id) REFERENCES public.work_plans(id);


--
-- Name: work_orders fk_rails_620904daa7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT fk_rails_620904daa7 FOREIGN KEY (work_plan_id) REFERENCES public.work_plans(id);


--
-- Name: aker_process_modules fk_rails_70ee2c6156; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_process_modules
    ADD CONSTRAINT fk_rails_70ee2c6156 FOREIGN KEY (aker_process_id) REFERENCES public.aker_processes(id);


--
-- Name: work_plans fk_rails_726b127a48; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_plans
    ADD CONSTRAINT fk_rails_726b127a48 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: aker_product_processes fk_rails_7af98dbc24; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_product_processes
    ADD CONSTRAINT fk_rails_7af98dbc24 FOREIGN KEY (aker_process_id) REFERENCES public.aker_processes(id);


--
-- Name: work_orders fk_rails_837dcc1d05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT fk_rails_837dcc1d05 FOREIGN KEY (process_id) REFERENCES public.aker_processes(id);


--
-- Name: jobs fk_rails_8b401b6695; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT fk_rails_8b401b6695 FOREIGN KEY (work_order_id) REFERENCES public.work_orders(id);


--
-- Name: products fk_rails_a75fcac2cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_a75fcac2cc FOREIGN KEY (catalogue_id) REFERENCES public.catalogues(id);


--
-- Name: work_plans fk_rails_aa13f61d0b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_plans
    ADD CONSTRAINT fk_rails_aa13f61d0b FOREIGN KEY (data_release_strategy_id) REFERENCES public.data_release_strategies(id);


--
-- Name: aker_product_processes fk_rails_ad31b9e5d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aker_product_processes
    ADD CONSTRAINT fk_rails_ad31b9e5d1 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: process_module_choices fk_rails_be1fa10a0a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.process_module_choices
    ADD CONSTRAINT fk_rails_be1fa10a0a FOREIGN KEY (aker_process_module_id) REFERENCES public.aker_process_modules(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20161024124011'),
('20161024153329'),
('20161027122250'),
('20161027122321'),
('20161027133241'),
('20161027133249'),
('20161027133255'),
('20170223151731'),
('20170224102355'),
('20170317161654'),
('20170317161712'),
('20170320134308'),
('20170320134812'),
('20170331103353'),
('20170419101909'),
('20170419101916'),
('20170511150048'),
('20170526134612'),
('20170601150847'),
('20170602144533'),
('20170609092536'),
('20170703111758'),
('20170718094004'),
('20170914081304'),
('20170925143838'),
('20170925150957'),
('20171019104645'),
('20171026124133'),
('20171113094502'),
('20180131161610'),
('20180131161643'),
('20180131161707'),
('20180131161729'),
('20180208140900'),
('20180212102251'),
('20180212141820'),
('20180213141025'),
('20180222113320'),
('20180222121021'),
('20180301100944'),
('20180301103636'),
('20180301150923'),
('20180316152215'),
('20180319095707'),
('20180328142742'),
('20180409145654'),
('20180416131952'),
('20180423135801'),
('20180523125115'),
('20180523125254'),
('20180531084456'),
('20180606103131'),
('20180606105059'),
('20180614131014'),
('20180807150205'),
('20180816103146'),
('20181123100354'),
('20181126100544'),
('20181127141215'),
('20181219110644'),
('20190122103226');


