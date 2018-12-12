import React from 'react';
import ReactDOM from 'react-dom';
import { tatString } from '../helpers/product';

const ProductInformation = (props) => {
  const { data } = props;

  return (
    <div className="col-md-6">
      <h5>Product Information</h5>
      <pre>{`Requested biomaterial type: ${data.requested_biomaterial_type}
Product version: ${data.product_version}
Total turn around time: ${tatString(data.total_tat)}
Description: ${data.description}
Availability: ${data.availability ? 'available' : 'suspended'}`}</pre>
    </div>
  );
}

export default ProductInformation;