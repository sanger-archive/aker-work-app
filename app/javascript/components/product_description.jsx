import React, { Fragment } from 'react';
import Select from 'react-select';
import ReactDOM from 'react-dom'

class ProductDescription extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      selectedPath: this.props.defaultPath
    }
    this.onSelectChange = this.onSelectChange.bind(this);
  }

  onSelectChange(event) {
    event.preventDefault();
    const newPath = this.state.selectedPath;
    newPath[event.target.id]= event.target.value
    this.setState({selectedPath: newPath})
  }

  render() {
    const links = this.props.availableLinks
    const selectedPath = this.state.selectedPath
    return (
      <div>
        <SelectLabel />
        <SelectDropdowns links={links} path={selectedPath} onChange={this.onSelectChange}/>
      </div>
    );
  }
}

class SelectLabel extends React.Component {
  render() {
    return (
      <Fragment>
        <label>Choose options:</label>
        <br />
      </Fragment>
    );
  }
}

class SelectDropdowns extends React.Component {
  render() {
    const select_dropdowns = [];
    let options= [];

    const links = this.props.links;
    const path = this.props.path;

    path.forEach((name, index)=>{
      if (index == 0) {
        options = links.start;
      } else {
        options = links[path[index-1]]
        if (options.length==1 && options.includes('end')) {
          return;
        }
      }
      select_dropdowns.push(<SelectElement selected={name} options={options} key={index} id={index} onChange={this.props.onChange} />)
    })

    return (
      <Fragment>
        { select_dropdowns }
      </Fragment>
    );
  }
}

class SelectElement extends React.Component {
  render() {
    const select_options = [];
    this.props.options.forEach((option, index) => {
      select_options.push(<SelectOption name={option} key={index} />)
    })
    return (
      <select value={this.props.selected} onChange={this.props.onChange} id={this.props.id}>
        { select_options }
      </select>
    )
  }
}

class SelectOption extends React.Component {
  render() {
   const option_name = this.props.name;
    return (
      <Fragment>
        <option value={option_name}>{option_name}</option>
      </Fragment>
    );
  }
}

export default ProductDescription;