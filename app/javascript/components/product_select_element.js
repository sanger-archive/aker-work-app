import React, { Fragment } from 'react';
import ReactDOM from 'react-dom';

const ProductSelectElement = (props) => {
  const { catalogueList, selectedProductId, enabled, onChange } = props;

  const optionGroups = catalogueList.map((catalogue, index) => {
    let name = catalogue[0];
    let productList = catalogue[1];

    return (
      <ProductOptionGroup key={index} index={index} name={name} productList={productList} />
    );
  });

  return (
    <select value={selectedProductId} className="form-control" onChange={onChange} disabled={!enabled}>
      { optionGroups }
    </select>
  );
}

export default ProductSelectElement;

const ProductOptionGroup = (props) => {
  const { name, productList } = props;

  const options = productList.map((product, index) => {
    return <ProductOption key={index} product={product} />;
  });

  return (
    <optgroup label={name}>
      { options }
    </optgroup>
  );
}

const ProductOption = (props) => {
  const { product } = props;
  const productName = product[0];
  const productId = product[1];

  return <option id={productId} value={productId}>{productName} </option>;
}