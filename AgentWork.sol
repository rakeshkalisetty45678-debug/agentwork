// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISomniaAgent {
    function queryAPI(string memory url, string memory method) external returns (string memory);
    function runAIModel(uint id, string memory input) external returns (string memory);
}

contract AgentRegistry {
    struct Agent {
        string name;
        address agentAddress;
        string[] skills;
        uint8 status; // 0: inactive, 1: active, 2: working
        uint reputation;
    }
    
    struct Company {
        string name;
        address owner;
        uint256 createdAt;
        uint agentsCount;
        uint totalTasks;
        uint revenue;
    }
    
    mapping(uint => Agent) public agents;
    mapping(uint => Company) public companies;
    mapping(address => uint[]) public userCompanies;
    
    uint public agentCounter;
    uint public companyCounter;
    
    event AgentRegistered(uint indexed agentId, string name, address agentAddress);
    event CompanyRegistered(uint indexed companyId, string name, address owner);
    event AgentHired(uint indexed companyId, uint indexed agentId);
    event TaskCompleted(uint indexed companyId, uint taskId, uint reward);
    
    function registerAgent(string memory _name, string[] memory _skills) external returns (uint) {
        agentCounter++;
        agents[agentCounter] = Agent(_name, msg.sender, _skills, 1, 100);
        emit AgentRegistered(agentCounter, _name, msg.sender);
        return agentCounter;
    }
    
    function registerCompany(string memory _name) external returns (uint) {
        companyCounter++;
        companies[companyCounter] = Company(_name, msg.sender, block.timestamp, 0, 0, 0);
        userCompanies[msg.sender].push(companyCounter);
        emit CompanyRegistered(companyCounter, _name, msg.sender);
        return companyCounter;
    }
    
    function hireAgent(uint _companyId, uint _agentId) external {
        require(companies[_companyId].owner == msg.sender, "Not owner");
        require(agents[_agentId].status == 1, "Agent not available");
        
        companies[_companyId].agentsCount++;
        agents[_agentId].status = 2;
        
        emit AgentHired(_companyId, _agentId);
    }
    
    function completeTask(uint _companyId, uint _reward) external {
        require(companies[_companyId].owner == msg.sender, "Not owner");
        companies[_companyId].totalTasks++;
        companies[_companyId].revenue += _reward;
        
        emit TaskCompleted(_companyId, companies[_companyId].totalTasks, _reward);
    }
}

contract Escrow {
    mapping(uint => EscrowAgreement) public agreements;
    uint public agreementCounter;
    
    struct EscrowAgreement {
        address payer;
        address payee;
        uint256 amount;
        uint8 status; // 0: pending, 1: released, 2: refunded
        uint256 createdAt;
    }
    
    event EscrowCreated(uint indexed agreementId, address payer, address payee, uint256 amount);
    event EscrowReleased(uint indexed agreementId, address payee, uint256 amount);
    
    function createEscrow(address _payee, uint256 _amount) external payable returns (uint) {
        require(msg.value == _amount, "Incorrect amount");
        
        agreementCounter++;
        agreements[agreementCounter] = EscrowAgreement(msg.sender, _payee, _amount, 0, block.timestamp);
        
        emit EscrowCreated(agreementCounter, msg.sender, _payee, _amount);
        return agreementCounter;
    }
    
    function releaseEscrow(uint _agreementId) external {
        EscrowAgreement storage agreement = agreements[_agreementId];
        require(msg.sender == agreement.payer, "Not payer");
        require(agreement.status == 0, "Already processed");
        
        agreement.status = 1;
        payable(agreement.payee).transfer(agreement.amount);
        
        emit EscrowReleased(_agreementId, agreement.payee, agreement.amount);
    }
}

contract Reputation {
    mapping(address => uint) public reputation;
    mapping(address => mapping(address => uint)) public ratings;
    
    event ReputationUpdated(address indexed user, uint newScore);
    event RatingSubmitted(address indexed rater, address indexed rated, uint score);
    
    function updateReputation(address _user, uint _score) external {
        reputation[_user] = _score;
        emit ReputationUpdated(_user, _score);
    }
    
    function rateAgent(address _agent, uint _score) external {
        require(_score >= 1 && _score <= 100, "Score must be 1-100");
        ratings[msg.sender][_agent] = _score;
        
        // Update average reputation
        // Simplified: in production, you'd calculate average from all ratings
        reputation[_agent] = _score;
        
        emit RatingSubmitted(msg.sender, _agent, _score);
    }
    
    function getReputation(address _user) external view returns (uint) {
        return reputation[_user];
    }
}
