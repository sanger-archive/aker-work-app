import React, { Fragment } from 'react';
import ReactDOM from 'react-dom';
import ProcessModuleSelectElement from './process_module_select_element';

const ProcessModulesSelectDropdowns = (props) => {
  const { links, path, processStageId, enabled, onChange } = props;

  const select_dropdowns = [];
  let options= [];

  path.forEach((obj, index) => {
    if (index == 0) {
      options = links.start;
    } else {
      options = links[path[index-1].name]
      if ((!options) || (options.length==1 && options.includes('end'))) {
        return;
      }
    }

    let selected = options.find((option) => { return obj.id == option.id })

    if (!selected) {
      selected = options[0];
    }

    select_dropdowns.push(
      <ProcessModuleSelectElement
        processStageId={processStageId}
        selected={selected}
        selectedValueForChoice={obj.selected_value}
        options={options}
        key={index}
        id={index}
        onChange={onChange}
        enabled={enabled}
      />
    )
  })

  return (
    <Fragment>
      { select_dropdowns }
    </Fragment>
  );
};

export default ProcessModulesSelectDropdowns;
