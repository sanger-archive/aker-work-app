// Utility functions for anything to do with Products/Processes/Process Modules/etc.

export const convertToCurrency = (input) => {
  return '£' + input.toFixed(2);
}

export const nameWithoutCost = (text) => {
  if (text==null) {
    return text;
  }
  const i = text.lastIndexOf(" (");
  if (i >= 0) {
    return text.substring(0,i);
  }
  return text;
}

export const tatString = (tat) => {
  if (tat==null) {
    return '';
  }
  if (tat==1) {
    return '1 day';
  }
  return tat.toString() + ' days';
}