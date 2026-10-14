/**
 * Small piece of "business logic" so the project has something
 * meaningful to unit-test. Kept deliberately simple.
 */

const OPERATIONS = {
  add: (a, b) => a + b,
  subtract: (a, b) => a - b,
  multiply: (a, b) => a * b,
  divide: (a, b) => {
    if (b === 0) {
      throw new Error('Division by zero is not allowed');
    }
    return a / b;
  },
};

/**
 * Converts a raw value (usually a query-string) into a finite number.
 * Throws if the value is missing or not numeric.
 */
function toNumber(value, name) {
  if (value === undefined || value === null || String(value).trim() === '') {
    throw new Error(`Parameter "${name}" is required`);
  }
  const num = Number(value);
  if (!Number.isFinite(num)) {
    throw new Error(`Parameter "${name}" must be a number`);
  }
  return num;
}

/**
 * Runs one calculator operation.
 * @param {string} op  add | subtract | multiply | divide
 * @param {number|string} a
 * @param {number|string} b
 * @returns {number}
 */
function calculate(op, a, b) {
  const fn = OPERATIONS[op];
  if (!fn) {
    throw new Error(
      `Unknown operation "${op}". Use one of: ${Object.keys(OPERATIONS).join(', ')}`
    );
  }
  return fn(toNumber(a, 'a'), toNumber(b, 'b'));
}

module.exports = { calculate, toNumber, OPERATIONS };
