/* Copyright (C) 2017 GovBlocks.io
  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
  This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
  You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/ */

pragma solidity 0.5.7;
import "./external/govblocks-protocol/interfaces/IMemberRoles.sol";
import "./external/govblocks-protocol/Governed.sol";
import "./Governance.sol";
import "./TokenController.sol";
import "./Iupgradable.sol";


contract MemberRoles is IMemberRoles, Governed, Iupgradable {

    TokenController internal tokenController;
    struct MemberRoleDetails {
        uint memberCounter;
        mapping(address => uint) memberIndex;
        address[] memberAddress;
        address authorized;
    }

    enum Role {UnAssigned, AdvisoryBoard, TokenHolder, DisputeResolution}

    MemberRoleDetails[] internal memberRoleData;
    bool internal constructorCheck;

    modifier checkRoleAuthority(uint _memberRoleId) {
        if (memberRoleData[_memberRoleId].authorized != address(0))
            require(msg.sender == memberRoleData[_memberRoleId].authorized);
        else
            require(isAuthorizedToGovern(msg.sender), "Not Authorized");
        _;
    }

    /**
     * @dev to swap advisory board member
     * @param _newABAddress is address of new AB member
     * @param _removeAB is advisory board member to be removed
     */
    function swapABMember (
        address _newABAddress,
        address _removeAB
    )
    external
    checkRoleAuthority(uint(Role.AdvisoryBoard)) {

        _updateRole(_newABAddress, uint(Role.AdvisoryBoard), true);
        _updateRole(_removeAB, uint(Role.AdvisoryBoard), false);

    }

    /**
     * @dev Iupgradable Interface to update dependent contract address
     */
    function changeDependentContractAddress() public {
        tokenController = TokenController(ms.getLatestAddress("TC"));
    }

    /**
     * @dev to change the master address
     * @param _masterAddress is the new master address
     */
    function changeMasterAddress(address _masterAddress) public {
        if (masterAddress != address(0))
            require(masterAddress == msg.sender);
        masterAddress = _masterAddress;
        ms = Master(_masterAddress);
        
    }
    
    /**
     * @dev to initiate the member roles
     * @param _firstAB is the address of the first AB member
     * @param memberAuthority is the authority (role) of the member
     */
    function memberRolesInitiate (address _firstAB, address memberAuthority) public {
        require(!constructorCheck);
        _addInitialMemberRoles(_firstAB, memberAuthority);
        constructorCheck = true;
    }

    /// @dev Adds new member role
    /// @param _roleName New role name
    /// @param _roleDescription New description hash
    /// @param _authorized Authorized member against every role id
    function addRole( //solhint-disable-line
        bytes32 _roleName,
        string memory _roleDescription,
        address _authorized
    )
    public
    onlyAuthorizedToGovern {
        _addRole(_roleName, _roleDescription, _authorized);
    }

    /// @dev Assign or Delete a member from specific role.
    /// @param _memberAddress Address of Member
    /// @param _roleId RoleId to update
    /// @param _active active is set to be True if we want to assign this role to member, False otherwise!
    function updateRole( //solhint-disable-line
        address _memberAddress,
        uint _roleId,
        bool _active
    )
    public
    checkRoleAuthority(_roleId) {
        _updateRole(_memberAddress, _roleId, _active);
    }

    /// @dev Return number of member roles
    function totalRoles() public view returns(uint256) { //solhint-disable-line
        return memberRoleData.length;
    }

    /// @dev Change Member Address who holds the authority to Add/Delete any member from specific role.
    /// @param _roleId roleId to update its Authorized Address
    /// @param _newAuthorized New authorized address against role id
    function changeAuthorized(uint _roleId, address _newAuthorized) public checkRoleAuthority(_roleId) { //solhint-disable-line
        memberRoleData[_roleId].authorized = _newAuthorized;
    }

    /// @dev Gets the member addresses assigned by a specific role
    /// @param _memberRoleId Member role id
    /// @return roleId Role id
    /// @return allMemberAddress Member addresses of specified role id
    function members(uint _memberRoleId) public view returns(uint, address[] memory memberArray) { //solhint-disable-line
        // uint length = memberRoleData[_memberRoleId].memberAddress.length;
        // uint i;
        // uint j = 0;
        // memberArray = new address[](memberRoleData[_memberRoleId].memberCounter);
        // for (i = 0; i < length; i++) {
        //     address member = memberRoleData[_memberRoleId].memberAddress[i];
        //     if (memberRoleData[_memberRoleId].memberIndex[member] > 0) { //solhint-disable-line
        //         memberArray[j] = member;
        //         j++;
        //     }
        // }

        return (_memberRoleId, memberRoleData[_memberRoleId].memberAddress);
    }

    /// @dev Gets all members' length
    /// @param _memberRoleId Member role id
    /// @return memberRoleData[_memberRoleId].memberCounter Member length
    function numberOfMembers(uint _memberRoleId) public view returns(uint) { //solhint-disable-line
        return memberRoleData[_memberRoleId].memberCounter;
    }

    /// @dev Return member address who holds the right to add/remove any member from specific role.
    function authorized(uint _memberRoleId) public view returns(address) { //solhint-disable-line
        return memberRoleData[_memberRoleId].authorized;
    }

    /// @dev Get All role ids array that has been assigned to a member so far.
    function roles(address _memberAddress) public view returns(uint[] memory) { //solhint-disable-line
        uint length = memberRoleData.length;
        uint[] memory assignedRoles = new uint[](length);
        uint counter = 0; 
        for (uint i = 1; i < length; i++) {
            if (memberRoleData[i].memberIndex[_memberAddress] > 0) {
                assignedRoles[counter] = i;
                counter++;
            }
        }
        if (tokenController.totalBalanceOf(_memberAddress) > 0) {
            assignedRoles[counter] = uint(Role.TokenHolder);
        }
        return assignedRoles;
    }

    /// @dev Returns true if the given role id is assigned to a member.
    /// @param _memberAddress Address of member
    /// @param _roleId Checks member's authenticity with the roleId.
    /// i.e. Returns true if this roleId is assigned to member
    function checkRole(address _memberAddress, uint _roleId) public view returns(bool) { //solhint-disable-line
        if (_roleId == uint(Role.UnAssigned)) {
            return true;
        }
        else if (_roleId == uint(Role.TokenHolder)) {
            if (tokenController.totalBalanceOf(_memberAddress) > 0) {
                return true;
            }
        }
        else if (memberRoleData[_roleId].memberIndex[_memberAddress] > 0) {//solhint-disable-line
            return true;
        }
        return false;
    }

    /// @dev Return total number of members assigned against each role id.
    /// @return totalMembers Total members in particular role id
    function getMemberLengthForAllRoles() public view returns(uint[] memory totalMembers) { //solhint-disable-line
        totalMembers = new uint[](memberRoleData.length);
        for (uint i = 0; i < memberRoleData.length; i++) {
            totalMembers[i] = numberOfMembers(i);
        }
    }

    /**
     * @dev to update the member roles
     * @param _memberAddress in concern
     * @param _roleId the id of role
     * @param _active if active is true, add the member, else remove it 
     */
    function _updateRole(address _memberAddress,
        uint _roleId,
        bool _active) internal {
        require(_roleId != uint(Role.TokenHolder), "Membership to Token holder is detected automatically");
        if (_active) {
            require(memberRoleData[_roleId].memberIndex[_memberAddress] == 0);
            memberRoleData[_roleId].memberCounter = SafeMath.add(memberRoleData[_roleId].memberCounter, 1);
            memberRoleData[_roleId].memberIndex[_memberAddress] = memberRoleData[_roleId].memberAddress.length;
            memberRoleData[_roleId].memberAddress.push(_memberAddress);
        } else {
            //Remove the selected member and swap its index with the member at last index
            require(memberRoleData[_roleId].memberIndex[_memberAddress] > 0);
            uint256 _memberIndex = memberRoleData[_roleId].memberIndex[_memberAddress];
            address _topElement = memberRoleData[_roleId].memberAddress[memberRoleData[_roleId].memberCounter];
            memberRoleData[_roleId].memberIndex[memberRoleData[_roleId].memberAddress[memberRoleData[_roleId].memberCounter]] = _memberIndex;
            memberRoleData[_roleId].memberCounter = SafeMath.sub(memberRoleData[_roleId].memberCounter, 1);
            memberRoleData[_roleId].memberAddress[_memberIndex] = _topElement;
            memberRoleData[_roleId].memberAddress.length--;
            delete memberRoleData[_roleId].memberIndex[_memberAddress];
        }
    }

    /// @dev Adds new member role
    /// @param _roleName New role name
    /// @param _roleDescription New description hash
    /// @param _authorized Authorized member against every role id
    function _addRole(
        bytes32 _roleName,
        string memory _roleDescription,
        address _authorized
    ) internal {
        emit MemberRole(memberRoleData.length, _roleName, _roleDescription);
        memberRoleData.push(MemberRoleDetails(0, new address[](0), _authorized));
    }

    /**
     * @dev to add initial member roles
     * @param _firstAB is the member address to be added
     * @param memberAuthority is the member authority(role) to be added for
     */
    function _addInitialMemberRoles(address _firstAB, address memberAuthority) internal {
        _addRole("Unassigned", "Unassigned", address(0));
        _addRole(
            "Advisory Board",
            "Selected few members that are deeply entrusted by the dApp. An ideal advisory board should be a mix of skills of domain, governance, research, technology, consulting etc to improve the performance of the dApp.", //solhint-disable-line
            address(0)
        );
        _addRole(
            "Token Holder",
            "Represents all users who hold dApp tokens. This is the most general category and anyone holding token balance is a part of this category by default.", //solhint-disable-line
            address(0)
        );
        _addRole(
            "DisputeResolution",
            "Represents members who are assigned to vote on resolving disputes", //solhint-disable-line
            memberAuthority
        );
        // _updateRole(_firstAB, uint(Role.AdvisoryBoard), true);
        // _updateRole(_firstAB, uint(Role.Owner), true);
        // _updateRole(_firstAB, uint(Role.Member), true);
    }

}