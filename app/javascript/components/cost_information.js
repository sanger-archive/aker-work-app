import React, { Fragment } from 'react';
import ReactDOM from 'react-dom';
import { convertToCurrency } from '../helpers/product';

const CostInformation = (props) => {
  const { numSamples, errors, unitPrice } = props;

  if (errors && errors.length) {
    let errorText = errors.join('\n');
    return (
      <div className="col-md-6">
        <h5>Cost Information</h5>
        <pre>{`Number of samples: ${numSamples}`}
          <span className="wrappable" style={{color: 'red'}}>&#9888; {`${errorText}`}</span>
        </pre>
      </div>
    );
  }

  const costPerSample = typeof(unitPrice)=='string' ? parseFloat(unitPrice) : unitPrice;

  if (costPerSample==null) {
    return <pre>{`Number of samples: ${numSamples}`}</pre>;
  }

  const total = numSamples * costPerSample;

  return (
    <div className="col-md-6">
      <h5>Cost Information</h5>
      <pre>{`Number of samples: ${numSamples}
Estimated cost per sample: ${convertToCurrency(costPerSample)}
Total: ${convertToCurrency(total)}
`}
        <span style={{color: 'red'}}>&#9888; These values come from mock UBW.</span>
      </pre>
    </div>
  );
};

export default CostInformation;