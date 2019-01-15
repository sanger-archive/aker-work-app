import EnzymeHelper from '../enzyme_helper'
import React, { Fragment } from 'react';
import { expect } from 'chai'
import { mount } from 'enzyme';
import ProcessModuleParameters from '../../../app/javascript/components/process_module_parameters';

describe('<ProcessModuleParameters />', () => {
  let selectedValue = 3

  context('when rendering it', () => {
    context('when there is no range of values to check', () => {
      let selectedOption = { }

      it('does not render the module selected value input', () => {
        let wrapper = mount(<ProcessModuleParameters selectedOption={selectedOption} selectedValueForChoice={selectedValue} />);
        expect(wrapper.find('input')).to.have.length(0);
      })

    })
    context('when there is a range of values to check', () =>  {
      let selectedOption = { min_value: 1, max_value: 5 }
      let wrapper = mount(<ProcessModuleParameters selectedOption={selectedOption} selectedValueForChoice={selectedValue} />);

      it('renders the module selected value input', () => {
        expect(wrapper.find('input')).to.have.length(1);
      })

      it('renders the value set as property', () =>  {
        expect(wrapper.find('input').props().value).to.equal(selectedValue)
      })

      context('when the selected value is an empty string', () => {
        it('has a warning class', ()=> {})
      })

      context('when changing the selected value', () => {
        it('changes the value', () => {
          let event = { target: { value: 4 }}
          wrapper.find('input').simulate('change', event)
          expect(wrapper.find('input').props().value).to.equal(4)
        })
        context('when writing a value lower than the min value', () => {
          beforeEach(() => {
            let event = { target: { value: 0 }}
            wrapper.find('input').simulate('change', event)
          })

          it('displays an error message', () => {
            expect(wrapper.find('input').props().value).to.equal(0)
            expect(wrapper.find('div.text-danger')).to.have.length(1)
          })
        })
        context('when writing a value higher than the max value', () => {
          beforeEach(() => {
            let event = { target: { value: 6 }}
            wrapper.find('input').simulate('change', event)
          })

          it('displays an error message', () => {
            expect(wrapper.find('input').props().value).to.equal(6)
            expect(wrapper.find('div.text-danger')).to.have.length(1)
          })
        })
        context('when writing a value in the range', () => {
          beforeEach(() => {
            let event = { target: { value: 3 }}
            wrapper.find('input').simulate('change', event)
          })

          it('does not display an error message', () => {
            expect(wrapper.find('input').props().value).to.equal(3)
            expect(wrapper.find('div.text-danger')).to.have.length(0)
          })

        })

      })
    })
  })
})
