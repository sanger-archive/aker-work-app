import React, { Fragment } from 'react';
import ReactDOM from 'react-dom'

class ProductDescription extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      selectedPath: this.props.defaultPath,
      showProductInfo: false
    }
    this.onProductOptionsSelectChange = this.onProductOptionsSelectChange.bind(this);
    this.onProductSelectChange = this.onProductSelectChange.bind(this);
    this.getProductInfo = this.getProductInfo.bind(this);
    this.processProductInfo = this.processProductInfo.bind(this);
    this.injectProductInfoIntoForm = this.injectProductInfoIntoForm.bind(this);
    this.checkResponse = this.checkResponse.bind(this);
    this.catchError = this.catchError.bind(this);
  }

  onProductSelectChange(event) {
    event.preventDefault();
    const selectedProductId = event.target.selectedOptions[0].id;
    if (selectedProductId) {
      this.setState({ showProductInfo: true })
      this.getProductInfo(selectedProductId);
    } else {
      this.setState({ showProductInfo: false })
    }
  }

  onProductOptionsSelectChange(event) {
    event.preventDefault();
    const newPath = this.state.selectedPath;
    const selectedName = event.target.selectedOptions[0].text
    const selectedId = event.target.value
    newPath[event.target.id] = {id: selectedId, name: selectedName}
    this.setState({selectedPath: newPath})
  }

  getProductInfo(productId) {
    const workOrderId = $("#work-order-id").val();
    const path = Routes.root_path()+'api/v1/work_orders/'+workOrderId+'/products/'+productId;

    fetch(path)
      .then(this.checkResponse)
      .then(this.processProductInfo)
      .catch(this.catchError)
  }

  checkResponse(response) {
    if (response.ok) {
      this.setState({errorMessage: null})
      return response.json()
    }
    return Promise.reject(Error(response.statusText))
  }

  catchError(error) {
    this.setState({errorMessage: error.message})
  }

  processProductInfo(responseJSON) {
    const links = responseJSON.available_links;
    const path = responseJSON.default_path;
    this.setState({selectedPath: path, availableLinks: links, productInfo: responseJSON})
  }

  injectProductInfoIntoForm(){
    const productId = this.state.productInfo.id;
    const productOptions = this.state.selectedPath;
    const productOptionIds = productOptions.map((product) => { return product.id});
    const encodesProductOptions = JSON.stringify(productOptionIds)

    $('#injected_product_id').html(
      "<input type='hidden' name='work_order[product_id]' value="+productId+">"
    )

    $('#injected_product_options').html(
      "<input type='hidden' name='work_order[product_options]' value="+encodesProductOptions+">"
    )
  }

  render() {
    var productOptionComponents = [];

    if (this.state.showProductInfo && this.state.productInfo) {
      this.injectProductInfoIntoForm();

      productOptionComponents = (
        <Fragment>
          <ProductOptionLabel />
          <ProductOptionSelectDropdowns links={this.state.availableLinks} path={this.state.selectedPath} onChange={this.onProductOptionsSelectChange}/>
          <ProductInformation data={this.state.productInfo} />
          <CostInformation data={this.state.productInfo} />
        </Fragment>
      );
    }

    return (
      <div>
        <ErrorConsole msg={this.state.errorMessage}/>
        <ProductLabel />
        <ProductSelectElement catalogueList={this.props.data} onChange={this.onProductSelectChange}/>
        { productOptionComponents }
      </div>
    );
  }
}

class ErrorConsole extends React.Component {
  render() {
    var error = <div></div>
    if (this.props.msg) {
      error = <div className='alert alert-danger'>{this.props.msg}</div>
    }
    return (
      error
    );
  }
}

class ProductLabel extends React.Component {
  render() {
    return (
      <Fragment>
        <label>Choose a product:</label>
        <br />
      </Fragment>
    );
  }
}

class ProductSelectElement extends React.Component {
  render() {
    let optionGroups = (
      <Fragment>
        <ProductSelectOptionGroup catalogueList={this.props.catalogueList}/>
      </Fragment>
    );

    return (
      <select onChange={this.props.onChange}>
        {optionGroups}
      </select>
    );
  }
}

class ProductSelectOptionGroup extends React.Component {
  render() {
    var optionGroups = [];

    this.props.catalogueList.forEach(function(catalogue, index) {
      let name = catalogue[0];
      let productList = catalogue[1];
      optionGroups.push(
        <optgroup key={index} label={name}>
          <ProductSelectOptGroupOption productList={productList}/>
        </optgroup>
      );
    });

    return (
      <Fragment>
        { optionGroups }
      </Fragment>
    )
  }
}

class ProductSelectOptGroupOption extends React.Component {
  render() {
    var options = [];

    this.props.productList.forEach(function(product, index){
      let productName = product[0]
      let productId = product[1]
      options.push(
        <option key={index} id={productId}>{productName}</option>
      );
    });

    return (
      <Fragment>
        { options }
      </Fragment>
    );
  }
}

class ProductOptionLabel extends React.Component {
  render() {
    return (
      <Fragment>
        <br />
        <label>Choose options:</label>
        <br />
      </Fragment>
    );
  }
}

class ProductOptionSelectDropdowns extends React.Component {
  render() {
    const select_dropdowns = [];
    let options= [];

    const links = this.props.links;
    const path = this.props.path;

    path.forEach((obj, index)=>{
      if (index == 0) {
        options = links.start;
      } else {
        options = links[path[index-1].name]
        if (options.length==1 && options.includes('end')) {
          return;
        }
      }
      select_dropdowns.push(<ProductOptionSelectElement selected={obj} options={options} key={index} id={index} onChange={this.props.onChange} />)
    })

    return (
      <Fragment>
        { select_dropdowns }
      </Fragment>
    );
  }
}

class ProductOptionSelectElement extends React.Component {
  render() {
    const select_options = [];
    this.props.options.forEach((option, index) => {
      select_options.push(<ProductOptionSelectOption obj={option} key={index} />)
    })
    return (
      <select value={this.props.selected.id} onChange={this.props.onChange} id={this.props.id}>
        { select_options }
      </select>
    )
  }
}

class ProductOptionSelectOption extends React.Component {
  render() {
   const productObject = this.props.obj;
    return (
      <Fragment>
        <option value={productObject.id}>{productObject.name}</option>
      </Fragment>
    );
  }
}

class ProductInformation extends React.Component {
  render() {
    const data = this.props.data;
    const cost = convertToCurrency(data.unit_price)
    return (
      <Fragment>
        <br />
          <pre>{`
            Cost per sample: ${cost}
            Requested biomaterial type: ${data.requested_biomaterial_type}
            Product version: ${data.product_version}
            TAT: ${data.tat}
            Description: ${data.description}
            Availability: ${data.availability}
            Product class: ${data.product_class}
          `}</pre>
      </Fragment>
    );
  }
}

class CostInformation extends React.Component {
  render() {
    const data = this.props.data;
    const numOfSamples = $("#num-of-samples").val();
    const costPerSample = data.unit_price;
    const total = numOfSamples * costPerSample;

    return (
      <Fragment>
          <pre>{`
            Number of samples: ${numOfSamples}
            Cost per sample: ${costPerSample}

            Total: ${total}
          `}</pre>
      </Fragment>
    );
  }
}

function convertToCurrency(input) {
  if (typeof(input)=='string') {
    input = parseInt(input)
  }
  return '£' + input.toFixed(2);
}

export default ProductDescription;