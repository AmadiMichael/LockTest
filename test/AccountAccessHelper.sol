// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

contract AccountAccessHelper is StdAssertions {
    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    enum StorageKind {
        Read,
        Write
    }

    function assertEq(VmSafe.AccountAccess[] memory a, VmSafe.AccountAccess[] memory b) internal {
        assertEq(a, b, "");
    }

    function assertEq(VmSafe.AccountAccess[] memory a, VmSafe.AccountAccess[] memory b, string memory err) internal {
        bool useErr = keccak256(abi.encode(err)) != keccak256(abi.encode(""));

        assertEq(a.length, b.length, "AccountAccess length mismatch");

        for (uint256 i; i < a.length; ++i) {
            assertEq(
                a[i].chainInfo.forkId,
                b[i].chainInfo.forkId,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].forkId mismatch")
            );
            assertEq(
                a[i].chainInfo.chainId,
                b[i].chainInfo.chainId,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].chainId mismatch")
            );
            assertTrue(
                a[i].kind == b[i].kind,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].kind mismatch")
            );
            assertEq(
                a[i].account,
                b[i].account,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].account mismatch")
            );
            assertEq(
                a[i].accessor,
                b[i].accessor,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].accessor mismatch")
            );
            assertEq(
                a[i].initialized,
                b[i].initialized,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].initialized mismatch")
            );
            assertEq(
                a[i].oldBalance,
                b[i].oldBalance,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].oldBalance mismatch")
            );
            assertEq(
                a[i].newBalance,
                b[i].newBalance,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].newBalance mismatch")
            );
            assertEq(
                keccak256(a[i].deployedCode),
                keccak256(b[i].deployedCode),
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].deployedCode mismatch")
            );
            assertEq(
                a[i].value,
                b[i].value,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].value mismatch")
            );
            assertEq(
                a[i].reverted,
                b[i].reverted,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].reverted mismatch")
            );

            assertEq(
                a[i].storageAccesses.length,
                b[i].storageAccesses.length,
                useErr ? err : string.concat("AccountAccess[", vm.toString(i), "].StorageAccess length mismatch")
            );
            for (uint256 j; j < a[i].storageAccesses.length; ++j) {
                assertEq(
                    a[i].storageAccesses[j].account,
                    b[i].storageAccesses[j].account,
                    useErr
                        ? err
                        : string.concat(
                            "AccountAccess[", vm.toString(i), "].StorageAccess[", vm.toString(j), "].account mismatch"
                        )
                );
                assertEq(
                    a[i].storageAccesses[j].slot,
                    b[i].storageAccesses[j].slot,
                    useErr
                        ? err
                        : string.concat(
                            "AccountAccess[", vm.toString(i), "].StorageAccess[", vm.toString(j), "].slot mismatch"
                        )
                );
                assertEq(
                    a[i].storageAccesses[j].isWrite,
                    b[i].storageAccesses[j].isWrite,
                    useErr
                        ? err
                        : string.concat(
                            "AccountAccess[", vm.toString(i), "].StorageAccess[", vm.toString(j), "].isWrite mismatch"
                        )
                );

                assertEq(
                    a[i].storageAccesses[j].previousValue,
                    b[i].storageAccesses[j].previousValue,
                    useErr
                        ? err
                        : string.concat(
                            "AccountAccess[", vm.toString(i), "].StorageAccess[", vm.toString(j), "].previousValue mismatch"
                        )
                );
                assertEq(
                    a[i].storageAccesses[j].newValue,
                    b[i].storageAccesses[j].newValue,
                    useErr
                        ? err
                        : string.concat(
                            "AccountAccess[", vm.toString(i), "].StorageAccess[", vm.toString(j), "].newValue mismatch"
                        )
                );
                assertEq(
                    a[i].storageAccesses[j].reverted,
                    b[i].storageAccesses[j].reverted,
                    useErr
                        ? err
                        : string.concat(
                            "AccountAccess[", vm.toString(i), "].StorageAccess[", vm.toString(j), "].reverted mismatch"
                        )
                );
            }
        }
    }

    function filterByAccessKind(VmSafe.AccountAccess[] memory accountAccesses, VmSafe.AccountAccessKind kind)
        internal
        pure
        returns (VmSafe.AccountAccess[] memory)
    {
        uint256 len;
        for (uint256 i; i < accountAccesses.length; ++i) {
            if (accountAccesses[i].kind == kind) ++len;
        }
        uint256 currentIndex;
        VmSafe.AccountAccess[] memory filteredAccountAccesses = new VmSafe.AccountAccess[](len);
        for (uint256 i; i < accountAccesses.length; ++i) {
            if (accountAccesses[i].kind == kind) {
                filteredAccountAccesses[currentIndex++] = accountAccesses[i];
            }
        }

        return filteredAccountAccesses;
    }

    function filterByStorageKind(VmSafe.StorageAccess[] memory storageAccesses, StorageKind kind)
        internal
        pure
        returns (VmSafe.StorageAccess[] memory)
    {
        uint256 len;
        for (uint256 i; i < storageAccesses.length; ++i) {
            if (storageAccesses[i].isWrite && kind == StorageKind.Write) ++len;
        }
        uint256 currentIndex;
        VmSafe.StorageAccess[] memory filteredStorageAccesses = new VmSafe.StorageAccess[](len);
        for (uint256 i; i < storageAccesses.length; ++i) {
            if (storageAccesses[i].isWrite && kind == StorageKind.Write) {
                filteredStorageAccesses[currentIndex++] = storageAccesses[i];
            }
        }

        return filteredStorageAccesses;
    }

    // mapping(key => any_type)
    function getMappingSlot(bytes32 key, bytes32 slot) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, slot));
    }

    // mapping(key => mapping(key2 => any_type))
    function getMappingSlot(bytes32 key, bytes32 key2, bytes32 slot) internal pure returns (bytes32) {
        return keccak256(abi.encode(key2, keccak256(abi.encode(key, slot))));
    }

    // mapping(key => mapping(key2 => mapping(key3 => any_type)))
    function getMappingSlot(bytes32 key, bytes32 key2, bytes32 key3, bytes32 slot) internal pure returns (bytes32) {
        return keccak256(abi.encode(key3, keccak256(abi.encode(key2, keccak256(abi.encode(key, slot))))));
    }

    function logAccountAccesses(VmSafe.AccountAccess[] memory accountAccesses) internal pure {
        for (uint256 i; i < accountAccesses.length; ++i) {
            console2.log("index: %s", i);
            console2.log("  chainInfo.forkId: %s", accountAccesses[i].chainInfo.forkId);
            console2.log("  chainInfo.chainId: %s", accountAccesses[i].chainInfo.chainId);
            console2.log(string.concat("  kind: ", toString(accountAccesses[i].kind)));
            console2.log("  account: %s", accountAccesses[i].account);
            console2.log("  accessor: %s", accountAccesses[i].accessor);
            console2.log("  initialized: %s", accountAccesses[i].initialized);
            console2.log("  oldBalance: %s", accountAccesses[i].oldBalance);
            console2.log("  newBalance: %s", accountAccesses[i].newBalance);
            console2.log(string.concat("  deployedCode: ", vm.toString(accountAccesses[i].deployedCode)));
            console2.log("  value: %s", accountAccesses[i].value);
            console2.log(string.concat("  data: ", vm.toString(accountAccesses[i].data)));
            console2.log("  reverted: %s", accountAccesses[i].reverted);

            for (uint256 j; j < accountAccesses[i].storageAccesses.length; ++j) {
                console2.log("  storage access index: %s", j);
                console2.log("      storageAccesses.account: %s", accountAccesses[i].storageAccesses[j].account);
                console2.log(
                    string.concat(
                        "      storageAccesses.slot: ", vm.toString(accountAccesses[i].storageAccesses[j].slot)
                    )
                );
                console2.log("      storageAccesses.isWrite: %s", accountAccesses[i].storageAccesses[j].isWrite);
                console2.log(
                    string.concat(
                        "      storageAccesses.previousValue: ",
                        vm.toString(accountAccesses[i].storageAccesses[j].previousValue)
                    )
                );
                console2.log(
                    string.concat(
                        "      storageAccesses.newValue: ", vm.toString(accountAccesses[i].storageAccesses[j].newValue)
                    )
                );
                console2.log(
                    string.concat(
                        "      storageAccesses.reverted: ", vm.toString(accountAccesses[i].storageAccesses[j].reverted)
                    )
                );
            }
        }
    }

    function toString(VmSafe.AccountAccessKind kind) internal pure returns (string memory) {
        if (kind == VmSafe.AccountAccessKind.Call) return "Call";
        else if (kind == VmSafe.AccountAccessKind.DelegateCall) return "DelegateCall";
        else if (kind == VmSafe.AccountAccessKind.CallCode) return "CallCode";
        else if (kind == VmSafe.AccountAccessKind.StaticCall) return "StaticCall";
        else if (kind == VmSafe.AccountAccessKind.Create) return "Create";
        else if (kind == VmSafe.AccountAccessKind.SelfDestruct) return "SelfDestruct";
        else if (kind == VmSafe.AccountAccessKind.Resume) return "Resume";
        else if (kind == VmSafe.AccountAccessKind.Balance) return "Balance";
        else if (kind == VmSafe.AccountAccessKind.Extcodesize) return "Extcodesize";
        else if (kind == VmSafe.AccountAccessKind.Extcodehash) return "Extcodehash";
        else if (kind == VmSafe.AccountAccessKind.Extcodecopy) return "Extcodecopy";
        else revert("AccountAccessHelper: Unsupported variant");
    }
}
