import React, { Fragment } from 'react';
import ReactDOM from 'react-dom'

export class ProductDescription extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      selectedProductProcesses: this.props.productProcesses,
      showProductInfo: false
    }
    this.onProductOptionsSelectChange = this.onProductOptionsSelectChange.bind(this);
    this.onProductSelectChange = this.onProductSelectChange.bind(this);
    this.getProductInfo = this.getProductInfo.bind(this);
    this.processProductInfo = this.processProductInfo.bind(this);
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

  onProductOptionsSelectChange(event/*, pro*/) {
    event.preventDefault();

// processStage is the stage of the process for a product
    const processStage = event.target.parentElement.id
    const selectElementId = parseInt(event.target.id, 10)

    const processModuleName = event.target.selectedOptions[0].text
    const processModuleId = event.target.value

    let updatedProductProcesses = this.state.selectedProductProcesses;
    let updatedProcessDefaultPath = updatedProductProcesses[processStage].default_path

    updatedProcessDefaultPath[selectElementId] = {id: processModuleId, name: processModuleName}
    if (updatedProductProcesses[processStage].available_links[processModuleName][0].name=='end') {
      updatedProcessDefaultPath[selectElementId+1] = {name: 'end', id: 'end'};
    }
    updatedProductProcesses[processStage].default_path = updatedProcessDefaultPath

    this.setState({selectedProductProcesses: updatedProductProcesses})
  }

  getProductInfo(productId) {
    const workPlanId = this.props.work_plan_id;
    const path = Routes.root_path()+'api/v1/work_plans/'+workPlanId+'/products/'+productId;

    fetch(path, {credentials: 'include'})
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
    const productInfo = responseJSON
    const productProcesses = responseJSON.product_processes;

    this.setState({selectedProductProcesses: productProcesses, productInfo: productInfo})
  }

  serializedProductOptions() {
    if (this.state.selectedProductProcesses) {
      let productOptionsIds = [];
      this.state.selectedProductProcesses.forEach(function(prod, i){
        let processModuleIds = []
        prod.default_path.forEach(function(mod, j){
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

  componentWillMount() {
    // debugger
  }

  render() {
    var productOptionComponents = [];
    // debugger
    // if (this.props.product_id){
    //   this.getProductInfo(this.props.product_id);
    //   this.setState({ showProductInfo: true })
    // }

    if (this.state.showProductInfo && this.state.productInfo) {
      productOptionComponents = (
        <Fragment>
          <Processes productProcesses={this.state.selectedProductProcesses} onChange={this.onProductOptionsSelectChange}/>

          <ProductInformation data={this.state.productInfo} />
          <CostInformation data={this.state.productInfo} />
        </Fragment>
      );
    }

    const productId = this.state.productInfo ? this.state.productInfo.id : ""

    return (
      <div>
        <ErrorConsole msg={this.state.errorMessage}/>
        <input type='hidden' name='work_plan[product_id]' value={productId} />
        <input type='hidden' id="product_options" name='work_plan[product_options]' value={this.serializedProductOptions()} />

        <ProductLabel />
        <ProductSelectElement catalogueList={this.props.data} onChange={this.onProductSelectChange} selectedProductId={productId} />
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
    const productId = this.props.selectedProductId;
    let optionGroups = (
      <Fragment>
        <ProductSelectOptionGroup catalogueList={this.props.catalogueList} selectedProductId={productId}/>
      </Fragment>
    );

    return (
      <select className="form-control" onChange={this.props.onChange}>
        {optionGroups}
      </select>
    );
  }
}

class ProductSelectOptionGroup extends React.Component {
  render() {
    var optionGroups = [];
    const productId = this.props.selectedProductId;
    this.props.catalogueList.forEach(function(catalogue, index) {
      let name = catalogue[0];
      let productList = catalogue[1];
      optionGroups.push(
        <optgroup key={index} label={name}>
          <ProductSelectOptGroupOption productList={productList} selectedProductId={productId} />
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
    const selectedProductId = this.props.selectedProductId;

    this.props.productList.forEach(function(product, index){
      let productName = product[0]
      let productId = product[1]

      if (productId==selectedProductId){
        options.push(
          <option selected key={index} id={productId}>{productName} </option>
        );
      } else {
        options.push(
          <option key={index} id={productId}>{productName} </option>
        );
      }
    });

    return (
      <Fragment>
        { options }
      </Fragment>
    );
  }
}

class Processes extends React.Component {
  render() {
    const onChange = this.props.onChange;
    const processComponents = this.props.productProcesses.map((pro, index) => <Process pro={pro} onChange={onChange} key={index} index={index} />);

    return (
      <Fragment>
        { processComponents }
      </Fragment>
    );
  }
}

class Process extends React.Component {

  render() {
    const {pro, index, onChange} = this.props;

    return (
      <Fragment>
        <ProcessNameLabel name={pro.name}/>
        <div id={index} className="col-md-12">
          <ProcessModulesSelectDropdowns links={pro.available_links} path={pro.default_path} onChange={onChange} enabled={pro.enabled}/>
        </div>
      </Fragment>
    )
  }
}

export class WorkOrderProcess extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      productProcess: this.props.pro,
    }
    this.handleChange = this.handleChange.bind(this)
  }

  handleChange(e, pro) {
    e.preventDefault()

    const processModuleSelectId = parseInt(e.target.id, 10)
    const processModuleName = e.target.selectedOptions[0].text
    const processModuleId = e.target.value

    let updatedProductProcess = this.state.productProcess;
    let updatedProcessDefaultPath = updatedProductProcess.default_path

    updatedProcessDefaultPath[processModuleSelectId] = {id: processModuleId, name: processModuleName}
    if (updatedProductProcess.available_links[processModuleName][0].name=='end') {
      updatedProcessDefaultPath[processModuleSelectId+1] = {name: 'end', id: 'end'};
    }
    updatedProductProcess.default_path = updatedProcessDefaultPath

    this.setState({productProcess: updatedProductProcess})
  }

  serializedProcessModules(){
    const processStage = this.props.index;
    let processModuleIds = []
    if (this.state.productProcess){
      this.state.productProcess.default_path.forEach(function(mod,i){
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
    const index = this.props.index;
    const pro = this.state.productProcess;
    return (
      <div>
        <input type='hidden' id='order_id' name='work_plan[work_order_id]' value={pro.work_order_id} />
        <input type='hidden' id="process_modules" name='work_plan[work_order_modules]' value={this.serializedProcessModules()} />

        <Process name={pro.name} pro={pro} index={index} onChange={ (e) => this.handleChange(e, pro) } />
      </div>

    );
  }
}

class ProcessNameLabel extends React.Component {
  render() {
    return (
      <Fragment>
        <br />
        <label>{this.props.name} process:</label>
        <br />
      </Fragment>
    );
  }
}

class ProcessModulesSelectDropdowns extends React.Component {
  render() {
    const select_dropdowns = [];
    let options= [];

    const {links, path} = this.props;

    path.forEach((obj, index)=>{
      if (index == 0) {
        options = links.start;
      } else {
        options = links[path[index-1].name]
        if ((!options) || (options.length==1 && options.includes('end'))) {
          return;
        }
      }
      let selected = options.filter((o) => { return obj.id == o.id})[0]
      if (!selected) {
        selected = options[0];
      }
      select_dropdowns.push(<ProcessModuleSelectElement selected={selected} options={options} key={index} id={index} onChange={this.props.onChange} enabled={this.props.enabled} />)
    })

    return (
      <Fragment>
        { select_dropdowns }
      </Fragment>
    );
  }
}

class ProcessModuleSelectElement extends React.Component {
  render() {
    const select_options = [];
    this.props.options.forEach((option, index) => {
      select_options.push(<ProcessModuleSelectOption obj={option} key={index} />)
    })
    const selection = this.props.selected ? this.props.selected.id : ""

    if (this.props.enabled) {
      return (
        <select className="form-control" value={selection} onChange={this.props.onChange} id={this.props.id}>
          { select_options }
        </select>
      )
    } else {
      return (
        <select className="form-control" value={selection} onChange={this.props.onChange} id={this.props.id} disabled>
          { select_options }
        </select>
      )
    }
  }
}

class ProcessModuleSelectOption extends React.Component {
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