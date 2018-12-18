import React from 'react';
import ReactDOM from 'react-dom';
import ProcessModuleSelectOption from './process_module_select_option';
import ProcessModuleParameters from './process_module_parameters';

const ProcessModuleSelectElement = (props) => {
  const { options, id, selected, processStageId, enabled, selectedValueForChoice, onChange } = props;

  const selectOptions = options.map((option, index) => <ProcessModuleSelectOption obj={option} key={index} />);
  const selection = selected ? selected.id : "";
  const selectedOption = options.find((opt) => { return (opt.id == selection) });

  return (
    <div className="row">
      <div className="col-md-6" id={processStageId}>
        <select className="form-control" value={selectedOption.id} onChange={onChange} id={id} disabled={!enabled}>
          { selectOptions }
        </select>
      </div>
      <div className="col-md-3">
        <ProcessModuleParameters selectedOption={selectedOption} selectedValueForChoice={selectedValueForChoice} enabled={enabled} />
      </div>
    </div>
  )
}

export default ProcessModuleSelectElement;