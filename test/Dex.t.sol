// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../src/Dex.sol";

contract CustomERC20 is ERC20 {// ERC20 토큰 생성 및 컨트랙트가 배포되는 즉시 최대 가능한 양의 토큰을 컨트랙트를 배포한 주소(msg.sender)로 발행
    constructor(string memory tokenName) ERC20(tokenName, tokenName) {
        _mint(msg.sender, type(uint).max);
    }
}

/*
 * Contract에서 필요한 만큼(또는 요청한 만큼)의 자산을 가져가도록 구현되어있다는 것을 가정하였습니다.
 * (transferFrom을 통해)
 */
contract DexTest is Test {
    Dex public dex;
    ERC20 tokenX;
    ERC20 tokenY;

    function setUp() public {// 테스트 환경을 설정하는 함수.
        tokenX = new CustomERC20("XXX");
        tokenY = new CustomERC20("YYY");// 테스트할 토큰 두개를 초기화

        dex = new Dex(address(tokenX), address(tokenY));// Dex 컨트랙트를 초기화

        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);// 테스트가 시작되기 전에 필요한 설정들 적용
    }

    function testAddLiquidity1() external {
        // 두번의 유동성 공급이 같은 조건에서 실행될 때 동일한 LP 토큰을 받는지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        assertEq(firstLPReturn, secondLPReturn, "AddLiquidity Error 1");
    }

    function testAddLiquidity2() external {
        // 두번째 유동성 공급이 첫번째보다 두배 더 많은 자산으로 이루어질 때, 받는 LP 토큰이 두배인지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        assertEq(firstLPReturn * 2, secondLPReturn, "AddLiquidity Error 2");
    }

    function testAddLiquidity3() external {
        // 첫번째 유동성 공급 후, 매우 높은 최소 LP 반환값을 설정했을 때 유동성 공급이 실패하는지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1000 ether, 1000 ether, firstLPReturn * 10001 / 10000));
        assertTrue(!success, "AddLiquidity minimum LP return error");
    }

    function testAddLiquidity4() external {
        // 유동성 공급이 토큰 비율에 맞지 않게 이루어질 때 실패하거나 반환값이 맞는지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        (bool success, bytes memory alret) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1000 ether, 4000 ether, 0));
        uint256 lpret = uint(bytes32(alret));
        assertTrue((firstLPReturn == lpret) || !success, "AddLiquidity imbalance add liquidity test error");
    }

    function testAddLiquidity5() external {
        // 승인 없이 유동성 공급을 시도했을 때와 잔액이 부족한 상태에서 유동성 공급을 시도했을 때 올바르게 실패하는지 확인하는 테스트
        address sender = vm.addr(1);
        tokenX.transfer(sender, 100 ether);
        tokenY.transfer(sender, 100 ether);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.startPrank(sender);
        dex.addLiquidity(1000 ether, 1000 ether, 0);

        tokenX.approve(address(dex), type(uint).max);
        tokenY.approve(address(dex), type(uint).max);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        dex.addLiquidity(1000 ether, 1000 ether, 0);

        vm.stopPrank();

    }

    function testAddLiquidity6() external {
        // 0개의 토큰으로 유동성 공급을 시도했을 때 실패하는지 확인하는 테스트
        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 0 ether, 0 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 1");
        (success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 1 ether, 0 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 2");
        (success, ) = address(dex).call(abi.encodeWithSelector(dex.addLiquidity.selector, 0 ether, 1 ether, 0));
        assertTrue(!success, "AddLiquidity invalid initialization check error - 3");
    }

    function testRemoveLiquidity1() external {
        // 유동성 공급 후, 올바른 양의 토큰이 반환되는지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (uint tx, uint ty) = dex.removeLiquidity(secondLPReturn, 0, 0);
        assertEq(tx, 1000 ether * 2, "RemoveLiquiidty tx error");
        assertEq(ty, 1000 ether * 2, "RemoveLiquiidty tx error");
    }

    function testRemoveLiquidity2() external {
        // 최소 반환값보다 적은 양의 토큰이 반환될 경우 실패하는지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.removeLiquidity.selector, secondLPReturn, 2001 ether, 2001 ether));
        assertTrue(!success, "RemoveLiquidity minimum return error");
    }

    function testRemoveLiquidity3() external {
        // 보유하고 있는 것보다 많은 LP 토큰을 제거하려고 할 때 실패하는지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.removeLiquidity.selector, secondLPReturn*2));
        assertTrue(!success, "RemoveLiquidity exceeds balance check error");
    }

    function testRemoveLiquidity4() external {
        // 여러 번의 스왑 후, 유동성 제거가 예상된 범위 내에서 수행되는지 확인하는 테스트
        uint firstLPReturn = dex.addLiquidity(1000 ether, 1000 ether, 0);
        emit log_named_uint("firstLPReturn", firstLPReturn);

        uint secondLPReturn = dex.addLiquidity(1000 ether * 2, 1000 ether * 2, 0);
        emit log_named_uint("secondLPReturn", secondLPReturn);

        uint sumX;
        uint sumY;
        for (uint i=0; i<100; i++) {
            sumX += dex.swap(0, 1000 ether, 0);
            sumY += dex.swap(1000 ether, 0, 0);
        }

        // usedX = 1000 ether * 100
        // usedY = 1000 ether * 100

        uint poolAmountX = 1000 ether + 1000 ether * 2; // initial value
        poolAmountX += 1000 ether * 100;
        uint poolAmountY = 1000 ether + 1000 ether * 2; // initial value
        poolAmountY += 1000 ether * 100;

        poolAmountX -= sumX;
        poolAmountY -= sumY;

        emit log_named_uint("remaining poolAmountX", poolAmountX);
        emit log_named_uint("remaining poolAmountY", poolAmountY);

        (uint rx, uint ry) = dex.removeLiquidity(firstLPReturn, 0, 0);

        bool successX = rx <= (poolAmountX * 10001 / 10000 / 3) && rx >= (poolAmountX * 9999 / 10000 / 3); // allow 0.01%;
        bool successY = ry <= (poolAmountY * 10001 / 10000 / 3) && ry >= (poolAmountY * 9999 / 10000 / 3); // allow 0.01%;
        assertTrue(successX, "remove liquidity after swap error; rx");
        assertTrue(successY, "remove liquidity after swap error; ry");
    }

    function testSwap1() external {
        // x -> y 스왑이 올바르게 수행되고, 예상된 출력값을 받는지 확인하는 테스트
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // x -> y
        uint output = dex.swap(300 ether, 0, 0);

        uint poolAmountX = 60000 ether + 3000 ether;
        uint poolAmountY = 80000 ether + 4000 ether;


        int expectedOutput = -(int(poolAmountX * poolAmountY) / int(poolAmountX + 300 ether)) + int(poolAmountY);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint uExpectedOutput = uint(expectedOutput);

        emit log_named_int("expected output", expectedOutput);
        emit log_named_uint("real output", output);

        bool success = output <= (uExpectedOutput * 10001 / 10000) && output >= (uExpectedOutput * 9999 / 10000); // allow 0.01%;
        assertTrue(success, "Swap test fail 1; expected != return");
    }

    function testSwap2() external {
        // y -> x 스왑이 올바르게 수행되고, 예상된 출력값을 받는지 확인하는 테스트
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        uint output = dex.swap(0, 6000 ether, 0);

        uint poolAmountX = 60000 ether + 3000 ether;
        uint poolAmountY = 80000 ether + 4000 ether;


        int expectedOutput = -(int(poolAmountY * poolAmountX) / int(poolAmountY + 6000 ether)) + int(poolAmountX);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint uExpectedOutput = uint(expectedOutput);

        emit log_named_int("expected output", expectedOutput);
        emit log_named_uint("real output", output);

        bool success = output <= (uExpectedOutput * 10001 / 10000) && output >= (uExpectedOutput * 9999 / 10000); // allow 0.01%;
        assertTrue(success, "Swap test fail 2; expected != return");
    }

    function testSwap3() external {
        // 유효하지 않은 입력값으로 스왑을 시도했을 때 실패하는지 확인하는 테스트
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        // check invalid swap
        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.swap.selector, 1, 6000 ether, 0));
        assertTrue(!success, "Swap test fail 3; invalid input test failed");
    }

    function testSwap4() external {
        // 최소 출력값보다 낮은 반환값을 예상했을 때, 스왑이 실패하는지 확인하는 테스트
        dex.addLiquidity(3000 ether, 4000 ether, 0);
        dex.addLiquidity(30000 ether * 2, 40000 ether * 2, 0);

        // y -> x
        uint poolAmountX = 60000 ether + 3000 ether;
        uint poolAmountY = 80000 ether + 4000 ether;


        int expectedOutput = -(int(poolAmountY * poolAmountX) / int(poolAmountY + 6000 ether)) + int(poolAmountX);
        expectedOutput = expectedOutput * 999 / 1000; // 0.1% fee
        uint uExpectedOutput = uint(expectedOutput);

        emit log_named_int("expected output", expectedOutput);

        (bool success, ) = address(dex).call(abi.encodeWithSelector(dex.swap.selector, 0, 6000 ether, uExpectedOutput * 1005 / 1000));
        assertTrue(!success, "Swap test fail 4; minimum ouput amount check failed");
    }

    function testAddLiquidity7() external {
        // Dex에 직접 토큰을 전송한 후, 유동성 공급이 올바르게 작동하는지 확인하는 테스트
        tokenX.transfer(address(dex), 1000 ether);// total liquidity는 여전히 0이라 가정
        uint lp = dex.addLiquidity(3000 ether, 4000 ether, 0);// lp=3000, total=3000
        emit log_named_uint("LP", lp);

        tokenX.transfer(address(dex), 1000 ether);
        uint lp2 = dex.addLiquidity(5000 ether, 4000 ether, 0);//
        emit log_named_uint("LP", lp);

        (uint rx, uint ry) = dex.removeLiquidity(lp, 0, 0);
        assertEq(rx, 5000 ether, "rx failed");
        assertEq(ry, 4000 ether, "ry failed");
    }
}
