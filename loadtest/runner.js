#!/usr/bin/env node
// A simple loadtest runner, compatible with the "loads"
// external-runner protocol:
//
//    http://loads.readthedocs.org/
//

const zmq = require('zmq');


// The default configuration for sending results back to the broker.
//
var defaults = {
  LOADS_ZMQ_RECEIVER: 'ipc:///tmp/loads-agent-receiver.ipc',
  LOADS_AGENT_ID: '0',
  LOADS_RUN_ID: '0',
  LOADS_STATUS: '1,1,1,1'
}


// Update default configuration based on environment variables.
//
for (var k in defaults) {
  if (defaults.hasOwnProperty(k) && process.env.hasOwnProperty(k)) {
    defaults[k] = process.env[k];
  }
}
delete k


//  A "Runner" object encapsulates all the state necessary to send
//  messages back to the broker.
//
function Runner(opts) {
  if (!opts) opts = {};
  for (var k in defaults) {
    if (defaults.hasOwnProperty(k) && !opts.hasOwnProperty(k)) {
      opts[k] = defaults[k];
    }
  }
  this.opts = opts;
}


//  Initialize internal state.
//
Runner.prototype.initialize = function initialize(cb) {
  this.context = new zmq.Context();
  this.socket = new zmq.Socket(this.context, zmq.ZMQ_PUSH);
  this.socket.connect(this.opts.LOADS_ZMQ_RECEIVER);
  return cb(null);
}


//  Finalize internal state.
//
Runner.prototype.finalize = function finalize(cb) {
  this.socket.close();
  this.context.close();
  delete this.socket;
  delete this.context;
  return cb(null);
}


//  Send a message back to the broker.
//
Runner.prototype.send = function send(type, data) {
  var to_send = {
    data_type: type,
    agent_id: this.opts.LOADS_AGENT_ID,
    run_id: this.opts.LOADS_RUN_ID,
    loads_status: this.opts.LOADS_STATUS.split(',')
  };
  if (data != undefined) {
    for (var k in data){
      if (data.hasOwnProperty(k)) {
        to_send[k] = data[k];
      }
    }
  }
  this.socket.send(new Buffer(JSON.stringify(to_send), 'utf8'));
}


// Execute each method of the given object as a test, sending
// stats back to the broker as we progress.
//
Runner.prototype.run = function run(tests, cb) {
  var self = this;

  // We'll run each callable property of the module in turn.
  var testnames = Object.keys(tests);

  // Looping callback to run all the tests.
  function doEachTest(cb) {

    // Find the next property that's actually a function.
    // When we run out of names, shift() will return undefined.
    var testname = testnames.shift();
    while (testname && typeof tests[testname] !== 'function') {
      testname = testnames.shift();
    }
    if (typeof testname === 'undefined') return cb(null);

    // Run the test, passing it a callback that also lets
    // it access this Runner object.
    self.send('startTest', {test: testname});
    var testcb = function(err) {
      if (err) {
        var exc_info = ["JSError", JSON.stringify(err), ""];
        self.send('addFailure', {test: testname, exc_info: exc_info});
      } else {
        self.send('addSuccess', {test: testname});
      }
      self.send('stopTest', {test: testname});
      process.nextTick(function() {
        doEachTest(cb);
      });
    }
    testcb.runner = self;
    tests[testname](testcb);
  }

  // Loop over all tests, running each in turn.
  doEachTest(function(err) {
    return cb(err);
  });
}


//  Convenience function for running tests from a module.
//
function run(tests, opts, cb) {
  // 'opts' argument is optional.
  if (typeof opts === 'function' && !cb) {
    cb = opts;
    opts = {};
  }
  // If given a string, load it as a module.
  if (typeof tests === 'string') {
    tests = require(tests);
  }
  var runner = new Runner(opts);
  runner.initialize(function(err) {
    if (err) return cb(err);
    runner.run(tests, function(err) {
      if (err) return cb(err);
      runner.finalize(cb);
    });
  });
}


// Exporting the useful stuffz.
//
module.exports = exports = {
  Runner: Runner,
  run: run,
  defaults: defaults
}


// When executed as a script, run tests on module given in command-line args.
// This makes it possible to run this directly as a loads external runner.
if (require.main === module) {
  process.title = 'loads.js';
  run(process.argv[2], function(err) {
    process.exit(err ? 1 : 0);
  });
}
