// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {UserOperation, UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import "solady/src/utils/ECDSA.sol";
import {IEntryPoint, EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {SimpleAccountFactory} from "account-abstraction/samples/SimpleAccountFactory.sol";
import {SimpleAccount} from "account-abstraction/samples/SimpleAccount.sol";

struct Owner {
    address addr;
    uint256 key;
}

contract GasTest is Test {
    EntryPoint public solidityEntryPoint = new EntryPoint();
    SimpleAccountFactory public simpleAccountFactory = new SimpleAccountFactory(solidityEntryPoint);

    Owner owner;

    function setUp() public {
        owner = Owner({key: uint256(1), addr: vm.addr(uint256(1))});
    }

    function testGasCalcDiff() public {
        SimpleAccount simpleAccount = simpleAccountFactory.createAccount(owner.addr, 0);
        vm.deal(address(simpleAccount), 1 ether);

        UserOperation memory simpleAccountUserOp = UserOperation({
            sender: address(simpleAccount),
            nonce: 0,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 60_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });
        simpleAccountUserOp.signature = getSolidityUOSignature(simpleAccountUserOp);

        bytes32 uoHash = solidityEntryPoint.getUserOpHash(simpleAccountUserOp);

        UserOperation[] memory simpleAccountOps = new UserOperation[](1);
        simpleAccountOps[0] = simpleAccountUserOp;

        uint256 entryPointGas = gasleft();
        solidityEntryPoint.handleOps(simpleAccountOps, payable(address(0xdeadbeef)));
        entryPointGas = entryPointGas - gasleft();

        vm.startPrank(address(solidityEntryPoint));
        uint256 directGas = gasleft();
        simpleAccount.validateUserOp(simpleAccountUserOp, uoHash, 1 wei);
        simpleAccount.execute(address(0x696969), 1 wei, "");
        directGas = directGas - gasleft();
        vm.stopPrank();

        console.log("entry point gas: %s", entryPointGas);
        console.log("direct gas: %s", directGas);
        console.log("gas diff: %s", entryPointGas - directGas);
    }

    function getSolidityUOSignature(UserOperation memory userOp) public returns (bytes memory) {
        bytes32 opHash = solidityEntryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, ECDSA.toEthSignedMessageHash(opHash));
        bytes memory signature = abi.encodePacked(r, s, v);
        return signature;
    }
}
