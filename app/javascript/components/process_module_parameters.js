import React from 'react';
import ReactDOM from 'react-dom';

class ProcessModuleParameters extends React.Component {
  constructor(props) {
    super(props)
    this.onChange = this.onChange.bind(this)
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
    if ((!this.props.selectedOption.min_value && !this.props.selectedOption.max_value)) {
      return null;
    }

    const caption = "Enter value between "+ this.props.selectedOption.min_value + " and "+this.props.selectedOption.max_value
    const name = "work_plan[work_order_modules]["+this.props.selectedOption.id+"][selected_value]"
    const disabled = !this.props.enabled

    return(
      <div className={this.classes()}>
        <input
          autoComplete="off"
          disabled={disabled}
          value={this.state.selectedValue}
          type="text"
          name={name}
          className="form-control"
          placeholder={caption}
          onChange={this.onChange}
        />
        {this.renderFeedback(caption)}
      </div>
    )
  }
}

export default ProcessModuleParameters;