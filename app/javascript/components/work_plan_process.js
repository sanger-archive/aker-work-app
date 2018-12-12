import React from 'react';
import ReactDOM from 'react-dom';
import Process from './process';
import { nameWithoutCost } from '../helpers/product';

export class WorkPlanProcess extends React.Component {
  constructor(props) {
    super(props)
    this.state = { productProcess: this.props.pro };
    this.handleChange = this.handleChange.bind(this)
  }

  handleChange(e) {
    e.preventDefault();

    const processModuleSelectId = parseInt(e.target.id);
    const processModuleName = nameWithoutCost(e.target.selectedOptions[0].text);
    const processModuleId = e.target.value;

    let updatedProductProcess = {...this.state.productProcess};
    let updatedProcessPath = updatedProductProcess.path.slice();

    if (typeof processModuleSelectId !== "undefined") {
      updatedProcessPath[processModuleSelectId] = {id: processModuleId, name: processModuleName};
    }

    if (processModuleName!=='end' && updatedProductProcess.links[processModuleName][0].name=='end') {
      updatedProcessPath[processModuleSelectId+1] = {name: 'end', id: 'end'};
    }

    updatedProductProcess.path = updatedProcessPath;

    this.setState({productProcess: updatedProductProcess});
  }

  serializedProcessModules(){
    const processStage = this.props.index;
    let processModuleIds = [];
    if (this.state.productProcess){
      this.state.productProcess.path.forEach(function(mod,i) {
        if (mod.id != 'end') {
          processModuleIds[i] = parseInt(mod.id);
        }
      })
      return JSON.stringify(processModuleIds)
    } else {
      return ""
    }
  }

  render() {
    const { index, work_plan_id, pro } = this.props;

    return (
      <div>
        <input type='hidden' id='work_plan_id' name='work_plan[id]' value={work_plan_id} />
        <input type='hidden' id='process_id' name='work_plan[process_id]' value={pro.id} />
        <input type='hidden' id='process_modules' name='work_plan[process_modules]' value={this.serializedProcessModules()} />

        <Process pro={this.state.productProcess} index={index} onChange={this.handleChange} />
      </div>

    );
  }
}