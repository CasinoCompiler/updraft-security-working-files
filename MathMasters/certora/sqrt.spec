methods {
    function swrt(uint256 x, uint256 y) external returns uint256 envfree;
    function mathMasterTopHalf(uint256 y) external returns uint256 envfree;
    function soladyTopHalf(uint256 x) external returns uint256 envfree;
}

definition WAD() returns uint256 = 1000000000000000000;


rule uniSqrtVSMathMastersSqrt(uint256 x) {
    assert(mathMasterTopHalf(x) == soladyTopHalf(x));
}