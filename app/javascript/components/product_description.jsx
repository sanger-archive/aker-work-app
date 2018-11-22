import React, { Fragment } from 'react';
import ReactDOM from 'react-dom'

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
    this.getProductInfo = this.getProductInfo.bind(this);
    this.processProductInfo = this.processProductInfo.bind(this);
    this.checkResponse = this.checkResponse.bind(this);
    this.catchError = this.catchError.bind(this);
    this.fetchUnitPrice = this.fetchUnitPrice.bind(this);
    this.selectedModuleIds = this.selectedModuleIds.bind(this);
    this.processUnitPrice = this.processUnitPrice.bind(this);
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
    const processStage = event.target.parentElement.id //parentElement.parentElement.id
    //event.target.parentElement.id
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

  componentWillMount() {
    // debugger
  }

  render() {
    var productOptionComponents = [];
    // if (this.props.product_id){
    //   this.getProductInfo(this.props.product_id);
    //   this.setState({ showProductInfo: true })
    // }
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

class ProductSelectElement extends React.Component {
  render() {
    const productId = this.props.selectedProductId;
    let optionGroups = (
      <Fragment>
        <ProductSelectOptionGroup catalogueList={this.props.catalogueList} selectedProductId={productId}/>
      </Fragment>
    );

    return (
      <select className="form-control" onChange={this.props.onChange} disabled={!this.props.enabled}>
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
    const enabled = this.props.enabled;
    // Here process is an actual process
    function makeProcess(process, index) {
      const pro = { links: process.links, path: process.path, name: process.name,
        tat: process.tat, process_class: process.process_class, enabled: enabled };
      return (
        <Process pro={pro} onChange={onChange} index={index} key={index} />
      );
    }
    const processComponents = this.props.productProcesses.map((process, index) => makeProcess(process, index));

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
    let element;

    if (pro.name != null) {
      element = (
        <div className="panel panel-default">
          <div className="panel-heading">
            <div className="panel-title">
              {pro.name}
            </div>
          </div>
          <div className="panel-body">
            <span className="label label-success" style={{"fontSize": "12px", "marginRight": "5px"}}>{tatString(pro.tat)} turnaround</span>
            <span className="label label-primary" style={{"fontSize": "12px"}}>Process Class: {pro.process_class}</span>
            <div id={index}>
              <h5>Process Modules</h5>
              <ProcessModulesSelectDropdowns processStageId={index} links={pro.links} path={pro.path} onChange={onChange} enabled={pro.enabled}/>
            </div>
          </div>
        </div>
      );
    } else {
      element = (
        <div id={index}>
          <h5>Process Modules</h5>
          <ProcessModulesSelectDropdowns processStageId={index} links={pro.links} path={pro.path} onChange={onChange} enabled={pro.enabled}/>
        </div>
      );
    }

    return (
      <Fragment>
        { element }
      </Fragment>
    )
  }
}

// This is part of the dispatch page
export class WorkOrderProcess extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      productProcess: this.props.pro,
      work_order_id: this.props.work_order_id,
      index: this.props.index,
    }
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
    updatedProductProcess.path = updatedProcessPath

    this.setState({productProcess: updatedProductProcess})
  }

  serializedProcessModules(){
    const processStage = this.props.index;
    let processModuleIds = []
    if (this.state.productProcess){
      this.state.productProcess.path.forEach(function(mod,i){
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
    const index = this.state.index;
    const pro = this.state.productProcess;
    const order_id = this.state.work_order_id;
    return (
      <div>
        <input type='hidden' id='order_id' name='work_plan[work_order_id]' value={order_id} />
        <input type='hidden' id="process_modules" name='work_plan[work_order_modules]' value={this.serializedProcessModules()} />

        <Process pro={pro} index={index} onChange={this.handleChange} />
      </div>

    );
  }
}

class ProcessModulesSelectDropdowns extends React.Component {
  render() {
    const select_dropdowns = [];
    let options= [];

    const {links, path} = this.props;

    path.forEach((obj, index) => {
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
      select_dropdowns.push(<ProcessModuleSelectElement processStageId={this.props.processStageId} selected={selected} selectedValueForChoice={obj.selected_value} options={options} key={index} id={index} onChange={this.props.onChange} enabled={this.props.enabled} />)
    })

    return (
      <Fragment>
        { select_dropdowns }
      </Fragment>
    );
  }
}

export class ProcessModuleParameters extends React.Component {
  constructor(props) {
    super(props)
    this.validValue = this.validValue.bind(this)
    this.classes = this.classes.bind(this)
    this.onChange = this.onChange.bind(this)
    this.renderFeedback = this.renderFeedback.bind(this)
    this.state = {
      selectedValue: this.props.selectedValueForChoice || ""
    }
  }
  validValue() {
    return(
      (this.state.selectedValue >= this.props.selectedOption.min_value) &&
      (this.state.selectedValue <= this.props.selectedOption.max_value)
    )
  }
  onChange(e) {
    this.setState({selectedValue: e.target.value})
  }
  classes() {
    let list = []

    if (this.state.selectedValue && this.state.selectedValue.toString().length > 0) {
      if (this.validValue()) {
        list.push("has-success")
      } else {
        list.push("has-error")
      }
    } else {
      list.push("has-warning")
    }
    return list.join(' ')
  }
  renderFeedback(caption) {
    if ((this.validValue()) || ((this.state.selectedValue.length === 0))) {
      return(null)
    } else {
      return(
        <div className="text-danger">
            {caption}
        </div>
        )
    }
  }
  render() {
    if ((this.props.selectedOption.min_value || this.props.selectedOption.max_value)) {
      const caption = "Enter value between "+ this.props.selectedOption.min_value + " and "+this.props.selectedOption.max_value
      const name = "work_plan[work_order_module]["+this.props.selectedOption.id+"][selected_value]"
      const disabled = !this.props.enabled
      return(
        <div className={this.classes()}>
          <input autoComplete="off" disabled={disabled} value={this.state.selectedValue} type="text" name={name} className="form-control" placeholder={caption} onChange={this.onChange} />
          {this.renderFeedback(caption)}
        </div>
      )
    } else {
      return(null)
    }
  }
}

class ProcessModuleSelectElement extends React.Component {
  constructor(props) {
    super(props)
    this.renderSelect = this.renderSelect.bind(this)
  }
  renderSelect(select_options, selection) {
    return(
      <select className="form-control" value={selection} onChange={this.props.onChange} id={this.props.id} disabled={!this.props.enabled}>
        { select_options }
      </select>
    )
  }
  render() {
    const select_options = [];
    this.props.options.forEach((option, index) => {
      select_options.push(<ProcessModuleSelectOption obj={option} key={index} />)
    })
    const selection = this.props.selected ? this.props.selected.id : ""

    const selectedOption = this.props.options.filter((opt) => { return (opt.id == selection) })[0]
    return(
      <div className="row">
        <div className="col-md-6" id={this.props.processStageId}>
          { this.renderSelect(select_options, selection) }
        </div>
        <div className="col-md-3">
          <ProcessModuleParameters selectedOption={selectedOption} selectedValueForChoice={this.props.selectedValueForChoice} enabled={this.props.enabled} />
        </div>
      </div>
    )
  }
}

class ProcessModuleSelectOption extends React.Component {
  render() {
    const productObject = this.props.obj;
    let text = productObject.name;
    let disabled = false;
    if (productObject.cost!=null) {
      text += ' ('+convertToCurrency(parseFloat(productObject.cost))+' per sample)';
    } else if (text!='end') {
      text += ' (not available for this cost code)';
      disabled = true;
    }
    return (
      <Fragment>
        <option value={productObject.id} disabled={disabled}>{text}</option>
      </Fragment>
    );
  }
}

class ProductInformation extends React.Component {
  render() {
    const data = this.props.data;
    return (
      <Fragment>
        <div className="col-md-6">
        <h5>Product Information</h5>
        <pre>{`Requested biomaterial type: ${data.requested_biomaterial_type}
Product version: ${data.product_version}
Total turn around time: ${tatString(data.total_tat)}
Description: ${data.description}
Availability: ${data.availability ? 'available' : 'suspended'}`}</pre>
        </div>
      </Fragment>
    );
  }
}

class CostInformation extends React.Component {
  render() {
    const numSamples = this.props.numSamples;

    if (this.props.errors && this.props.errors.length) {
      let errorText = this.props.errors.join('\n');
      return (
        <Fragment>
        <div className="col-md-6">
          <h5>Cost Information</h5>
          <pre>{`Number of samples: ${numSamples}
`}
<span className="wrappable" style={{color: 'red'}}>&#9888; {`${errorText}`}</span></pre>
        </div>
        </Fragment>
      );
    }

    const costPerSample = typeof(this.props.unitPrice)=='string' ? parseFloat(this.props.unitPrice) : this.props.unitPrice;

    if (costPerSample==null) {
      return (
        <Fragment>
            <pre>{`Number of samples: ${numSamples}`}</pre>
        </Fragment>
      );
    }

    const total = numSamples * costPerSample;

    return (
      <Fragment>
      <div className="col-md-6">
        <h5>Cost Information</h5>
          <pre>{`Number of samples: ${numSamples}
Estimated cost per sample: ${convertToCurrency(costPerSample)}
Total: ${convertToCurrency(total)}
`}
<span style={{color: 'red'}}>&#9888; These values come from mock UBW.</span>
          </pre>
        </div>
      </Fragment>
    );
  }
}

function nameWithoutCost(text) {
  if (text==null) {
    return text;
  }
  const i = text.lastIndexOf(" (");
  if (i >= 0) {
    return text.substring(0,i);
  }
  return text;
}

function tatString(tat) {
  if (tat==null) {
    return '';
  }
  if (tat==1) {
    return '1 day';
  }
  return tat.toString() + ' days';
}

function convertToCurrency(input) {
  return '£' + input.toFixed(2);
}
