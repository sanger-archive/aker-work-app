import React, { Fragment } from 'react';
import ReactDOM from 'react-dom';
import ErrorConsole from './error_console';
import Processes from './processes';
import ProductInformation from './product_information';
import CostInformation from './cost_information';
import ProductSelectElement from './product_select_element';
import { nameWithoutCost } from '../helpers/product';

export class ProductDescription extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      selectedProductProcesses: this.props.productProcesses,
      showProductInfo: (this.props.productId!=null),
      enabled: this.props.enabled,
      numSamples: this.props.num_samples,
      pricing: { unitPrice: null, errors: null },
    }

    this.onProductOptionsSelectChange = this.onProductOptionsSelectChange.bind(this);
    this.onProductSelectChange = this.onProductSelectChange.bind(this);
    this.checkResponse = this.checkResponse.bind(this);
    this.catchError = this.catchError.bind(this);
    this.processUnitPrice = this.processUnitPrice.bind(this);
    this.processProductInfo = this.processProductInfo.bind(this);

    if (this.state.showProductInfo) {
      this.getProductInfo(this.props.productId);
    }
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

  onProductOptionsSelectChange(event/*, pro*/) {
    event.preventDefault();

    // processStage is the stage of the process for a product
    const processStage = event.target.parentElement.id
    const selectElementId = parseInt(event.target.id, 10)
    const processModuleName = nameWithoutCost(event.target.selectedOptions[0].text)
    const processModuleId = event.target.value

    let updatedProductProcesses = this.state.selectedProductProcesses.slice();
    let updatedProcessPath = updatedProductProcesses[processStage].path.slice();

    updatedProcessPath[selectElementId] = {id: processModuleId, name: processModuleName}

    if (processModuleName!=='end' && updatedProductProcesses[processStage].links[processModuleName][0].name=='end') {
      updatedProcessPath[selectElementId+1] = {name: 'end', id: 'end'};
    }
    updatedProductProcesses[processStage].path = updatedProcessPath

    this.setState({selectedProductProcesses: updatedProductProcesses});
    this.fetchUnitPrice();
  }

  getProductInfo(productId) {
    const workPlanId = this.props.work_plan_id;
    const path = Routes.root_path()+'api/v1/work_plans/'+workPlanId+'/products/'+productId;

    fetch(path, {credentials: 'include'})
      .then(this.checkResponse)
      .then(this.processProductInfo)
      .catch(this.catchError)
  }

  fetchUnitPrice() {
    const moduleIds = this.selectedModuleIds();
    const workPlanId = this.props.work_plan_id;

    this.setState({pricing: {unit_price: null, errors: null}});

    if (!moduleIds) {
      return;
    }

    const path = Routes.root_path()+'api/v1/work_plans/'+workPlanId+'/products/unit_price/'+moduleIds.join('-');

    fetch(path, {credentials: 'include'})
      .then(this.checkResponse)
      .then(this.processUnitPrice)
      .catch(this.catchError);
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
    const productInfo = responseJSON;
    const productProcesses = responseJSON.product_processes;

    this.setState({selectedProductProcesses: productProcesses, productInfo: productInfo})
    this.fetchUnitPrice();
  }

  processUnitPrice(responseJSON) {
    this.setState({pricing: { unitPrice: responseJSON.unit_price, errors: responseJSON.errors} });
  }

  selectedModuleIds() {
    if (!this.state.selectedProductProcesses) {
      return null;
    }
    let names = [];
    this.state.selectedProductProcesses.forEach(proc => {
      proc.path.forEach(mod => {
        if (mod.id!='end') {
          names.push(mod.id);
        }
      });
    });
    return names;
  }

  serializedProductOptions() {
    if (this.state.selectedProductProcesses) {
      let productOptionsIds = [];
      this.state.selectedProductProcesses.forEach(function(proc, i){
        let processModuleIds = [];
        proc.path.forEach(function(mod, j){
          if (mod.id != 'end') {
            processModuleIds[j] = parseInt(mod.id)
          }
        })
        productOptionsIds[i] = processModuleIds
      })
      return JSON.stringify(productOptionsIds)
    } else {
      return ""
    }
  }

  render() {
    var productOptionComponents = [];

    if (this.state.showProductInfo && this.state.productInfo) {
      productOptionComponents = (
        <Fragment>
          <h4>Processes</h4>
          <Processes productProcesses={this.state.selectedProductProcesses} onChange={this.onProductOptionsSelectChange} enabled={this.state.enabled}/>
          <div className="row">
            <ProductInformation data={this.state.productInfo} />
            <CostInformation numSamples={this.state.numSamples} unitPrice={this.state.pricing.unitPrice} errors={this.state.pricing.errors} />
          </div>
        </Fragment>
      );
    }

    const productId = this.state.productInfo ? this.state.productInfo.id : ""
    const enabled = this.state.enabled

    return (
      <div>
        <ErrorConsole msg={this.state.errorMessage}/>
        { enabled &&
          <input type='hidden' name='work_plan[product_id]' value={productId} />
        }
        { enabled &&
          <input type='hidden' id="product_options" name='work_plan[product_options]' value={this.serializedProductOptions()} />
        }

        <h4>Products</h4>
        <ProductSelectElement catalogueList={this.props.data} onChange={this.onProductSelectChange} selectedProductId={productId} enabled={this.state.enabled}/>
        <br/>
        { productOptionComponents }
      </div>
    );
  }
}