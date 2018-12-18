import React from 'react';
import ReactDOM from 'react-dom';

const ErrorConsole = (props) => {
  let error = <div></div>;
  if (props.msg) {
    error = <div className='alert alert-danger'>{props.msg}</div>
  }
  return error;
}

export default ErrorConsole;