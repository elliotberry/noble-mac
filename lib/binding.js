const { EventEmitter } = require('events');
const load = require('node-gyp-build');

const { NobleMac } = load(__dirname + '/..');

function attachEmitter(instance) {
  EventEmitter.call(instance);
  const methods = Object.getOwnPropertyNames(EventEmitter.prototype);
  for (const name of methods) {
    if (name !== 'constructor') {
      instance[name] = EventEmitter.prototype[name];
    }
  }
  return instance;
}

const instance = attachEmitter(new NobleMac());
instance.init();

module.exports = instance;
