import React from 'react';
import ReactDOM from 'react-dom';
import { convertToCurrency } from '../helpers/product';

const ProcessModuleSelectOption = (props) => {
  const process_module = props.obj;

  let text = process_module.name;
  let disabled = false;

  if (process_module.cost!=null) {
    text += ' ('+convertToCurrency(parseFloat(process_module.cost))+' per sample)';
  } else if (text!='end') {
    text += ' (not available for this cost code)';
    disabled = true;
  }
  return (
    <option value={process_module.id} disabled={disabled}>{text}</option>
  );
}

export default ProcessModuleSelectOption;