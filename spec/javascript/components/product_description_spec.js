import EnzymeHelper from '../enzyme_helper'
import React, { Fragment } from 'react';
import { expect } from 'chai'
import { shallow } from 'enzyme';
import { ProductDescription } from '../../../app/javascript/components/product_description';

describe('<ProductDescription />', () => {
  context('when rendering it', () => {
    it('renders the select element', () => {
      let wrapper = shallow(<ProductDescription />);
      expect(wrapper.find('ProductSelectElement')).to.have.length(1);
    })
  })
})