const { calculate, toNumber } = require('../src/utils/calculator');

describe('calculator - unit tests', () => {
  test('adds two numbers', () => {
    expect(calculate('add', 2, 3)).toBe(5);
  });

  test('subtracts two numbers', () => {
    expect(calculate('subtract', 10, 4)).toBe(6);
  });

  test('multiplies two numbers', () => {
    expect(calculate('multiply', 6, 7)).toBe(42);
  });

  test('divides two numbers', () => {
    expect(calculate('divide', 20, 4)).toBe(5);
  });

  test('accepts numeric strings (query-string values)', () => {
    expect(calculate('add', '1.5', '2.5')).toBe(4);
  });

  test('rejects division by zero', () => {
    expect(() => calculate('divide', 5, 0)).toThrow('Division by zero');
  });

  test('rejects unknown operations', () => {
    expect(() => calculate('power', 2, 3)).toThrow('Unknown operation');
  });

  test('rejects missing parameters', () => {
    expect(() => toNumber(undefined, 'a')).toThrow('"a" is required');
  });

  test('rejects non-numeric parameters', () => {
    expect(() => toNumber('abc', 'b')).toThrow('"b" must be a number');
  });
});
