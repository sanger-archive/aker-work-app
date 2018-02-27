import EnzymeHelper from '../enzyme_helper'

import React, { Fragment } from 'react';
import { expect } from 'chai'
import { shallow, mount } from 'enzyme';
import ProductDescription from "../../../app/javascript/components/product_description.jsx"

describe('<ProductDescription />', () => {
  context('when rendering it', () => {
    it('renders', () => {
      let wrapper = shallow(<ProductDescription />);
      expect(wrapper.find('div')).to.have.length(1);
    })
  })
})

