import React, { Fragment } from 'react';
import ReactDOM from 'react-dom';
import Process from './process';

const Processes = (props) => {
  const { onChange, enabled, productProcesses } = props;

  const processComponents = productProcesses.map((process, index) => {
    const pro = {
      enabled: enabled,
      ...process
    };

    return (
      <Process pro={pro} onChange={onChange} index={index} key={index} />
    );
  });

  return (
    <Fragment>
      { processComponents }
    </Fragment>
  );
}

export default Processes;