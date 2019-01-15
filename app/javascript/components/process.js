import React from 'react';
import ReactDOM from 'react-dom';
import { tatString } from '../helpers/product';
import ProcessModulesSelectDropdowns from './process_modules_select_dropdowns';

const Process = (props) => {
  const { pro, index, onChange } = props;

  if (pro.name != null) {
    return (
      <ProcessModulePanel process={pro} index={index}>
        <ProcessModulesSelectDropdowns
          processStageId={index}
          links={pro.links}
          path={pro.path}
          onChange={onChange}
          enabled={pro.enabled}
        />
      </ProcessModulePanel>
    );
  } else {
    return (
      <div id={index}>
        <h5>Process Modules</h5>
        <ProcessModulesSelectDropdowns
          processStageId={index}
          links={pro.links}
          path={pro.path}
          onChange={onChange}
          enabled={pro.enabled}
        />
      </div>
    );
  }
}

export default Process;

const ProcessModulePanel = (props) => {
  const { process, index, children } = props;

  return (
    <div className="panel panel-default">
      <div className="panel-heading">
        <div className="panel-title">
          {process.name}
        </div>
      </div>
      <div className="panel-body">
        <span className="label label-success" style={{"fontSize": "12px", "marginRight": "5px"}}>{tatString(process.tat)} turnaround</span>
        <span className="label label-primary" style={{"fontSize": "12px"}}>Process Class: {process.process_class}</span>
        <div id={index}>
          <h5>Process Modules</h5>
          { children }
        </div>
      </div>
    </div>
  )
}

