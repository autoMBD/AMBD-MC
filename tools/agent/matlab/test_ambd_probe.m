% SPDX-License-Identifier: MIT
function tests = test_ambd_probe
tests = functiontests(localfunctions);
end

function testPositive(testCase)
verifyEqual(testCase, ambd_probe(2), 6);
end

function testZero(testCase)
verifyEqual(testCase, ambd_probe(0), 0);
end

function testVector(testCase)
verifyEqual(testCase, ambd_probe([-1 0 2]), [-3 0 6]);
end
