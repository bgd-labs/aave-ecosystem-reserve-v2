```diff
diff --git a/etherscan/deployed/ecosystemReserve/AaveEcosystemReserveV2/src/contracts/AaveEcosystemReserveV2.sol b/flatten/AaveEcosystemReserveV2.sol
index d7ab568..efc6ffe 100644
--- a/etherscan/deployed/ecosystemReserve/AaveEcosystemReserveV2/src/contracts/AaveEcosystemReserveV2.sol
+++ b/flatten/AaveEcosystemReserveV2.sol
@@ -1,5 +1,5 @@
-// SPDX-License-Identifier: MIT
-pragma solidity ^0.8.8;
+// SPDX-License-Identifier: GPL-3.0
+pragma solidity 0.8.11;
 
 interface IERC20 {
   /**
@@ -75,6 +75,7 @@ interface IERC20 {
    */
   event Approval(address indexed owner, address indexed spender, uint256 value);
 }
+
 interface IStreamable {
     struct Stream {
         uint256 deposit;
@@ -145,8 +146,9 @@ interface IStreamable {
 
     function cancelStream(uint256 streamId) external returns (bool);
 
-    function initialize(uint256 proposalId, address aaveGovernanceV2) external;
+    function initialize(address fundsAdmin) external;
 }
+
 interface IAdminControlledEcosystemReserve {
     /** @notice Emitted when the funds admin changes
      * @param fundsAdmin The new funds admin
@@ -187,10 +189,15 @@ interface IAdminControlledEcosystemReserve {
         address recipient,
         uint256 amount
     ) external;
+
+    /**
+     * @notice Transfer the ownership of the funds administrator role.
+          This function should only be callable by the current funds administrator.
+     * @param admin The address of the new funds administrator
+     **/
+    function setFundsAdmin(address admin) external;
 }
-interface IAaveGovernanceV2 {
-    function submitVote(uint256 proposalId, bool support) external;
-}
+
 /**
  * @title VersionedInitializable
  *
@@ -233,15 +240,11 @@ abstract contract VersionedInitializable {
     // Reserved storage space to allow for layout changes in the future.
     uint256[50] private ______gap;
 }
+
 // OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)
 
-
-
-
 // OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)
 
-
-
 /**
  * @dev Collection of functions related to the address type
  */
@@ -583,10 +586,9 @@ library SafeERC20 {
         }
     }
 }
+
 // OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)
 
-
-
 /**
  * @dev Contract module that helps prevent reentrant calls to a function.
  *
@@ -646,7 +648,6 @@ abstract contract ReentrancyGuard {
     }
 }
 
-
 /**
  * @title AdminControlledEcosystemReserve
  * @notice Stores ERC20 tokens, and allows to dispose of them via approval or transfer dynamics
@@ -663,7 +664,7 @@ abstract contract AdminControlledEcosystemReserve is
 
     address internal _fundsAdmin;
 
-    uint256 public constant REVISION = 5;
+    uint256 public constant REVISION = 6;
 
     /// @inheritdoc IAdminControlledEcosystemReserve
     address public constant ETH_MOCK_ADDRESS =
@@ -707,6 +708,11 @@ abstract contract AdminControlledEcosystemReserve is
         }
     }
 
+    /// @inheritdoc IAdminControlledEcosystemReserve
+    function setFundsAdmin(address admin) external onlyFundsAdmin {
+        _setFundsAdmin(admin);
+    }
+
     /// @dev needed in order to receive ETH from the Aave v1 ecosystem reserve
     receive() external payable {}
 
@@ -716,7 +722,6 @@ abstract contract AdminControlledEcosystemReserve is
     }
 }
 
-
 /**
  * @title AaveEcosystemReserve v2
  * @notice Stores ERC20 tokens of an ecosystem reserve, adding streaming capabilities.
@@ -771,15 +776,9 @@ contract AaveEcosystemReserveV2 is
     }
 
     /*** Contract Logic Starts Here */
-    /**
-    * @dev initializes the ecosystem reserve with the logic to vote on proposal id
-    * @param proposalId id of the proposal which the ecosystem will vote on
-    * @param aaveGovernanceV2 address of the aave governance
-    */
-    function initialize(uint256 proposalId, address aaveGovernanceV2) external initializer {
-        // voting process
-        IAaveGovernanceV2 aaveGov = IAaveGovernanceV2(aaveGovernanceV2);
-        aaveGov.submitVote(proposalId, true);
+
+    function initialize(address fundsAdmin) external initializer {
+        _setFundsAdmin(fundsAdmin);
     }
 
     /*** View Functions ***/
@@ -1044,3 +1043,4 @@ contract AaveEcosystemReserveV2 is
         return true;
     }
 }
+
```
