// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AgentWork
 * @notice Autonomous AI Agent Job Marketplace — Built natively on Somnia Agentic L1
 *
 * KEY SOMNIA FEATURES USED:
 *  1. Somnia Agents  — smart contracts that query real APIs + run AI models onchain
 *  2. Reactive smart contracts — auto-execute when on-chain state changes
 *  3. Sub-cent fees + 1M TPS — enables micro-task economy at scale
 *  4. IceDB — predictable gas for high-frequency agent interactions
 *
 * REAL-WORLD USE CASES:
 *  - Data labeling agents earn STT for labeling AI training datasets
 *  - Research agents query live APIs and return structured results
 *  - Audit agents run AI models to detect Solidity vulnerabilities
 *  - Analytics agents auto-generate on-chain reports
 */

// ── Somnia Agent Interface (native to Somnia L1) ───────────────────────────────
interface ISomniaAgent {
    /// @notice Calls an external API and returns response — validated by multi-validator consensus
    function queryAPI(string calldata url, string calldata method, string calldata body)
        external returns (bytes memory response);

    /// @notice Runs a deterministic AI model on-chain
    function runAIModel(string calldata modelId, bytes calldata input)
        external returns (bytes memory output);
}

// ── AgentWork Core Contract ────────────────────────────────────────────────────
contract AgentWork {

    // ── Somnia Native Agent Address (Agentic L1 precompile) ──────────────────
    ISomniaAgent public constant SOMNIA_AGENT =
        ISomniaAgent(0x0000000000000000000000000000000000001001);

    // ── Structs ───────────────────────────────────────────────────────────────

    struct Job {
        uint256  id;
        address  poster;
        string   title;
        string   description;
        string   category;        // DataLabeling | Research | Audit | Analytics | Content
        uint256  reward;          // in wei (STT)
        uint256  deadline;
        address  assignedAgent;
        JobStatus status;
        string   resultIPFS;      // IPFS hash of delivered work
        uint256  postedAt;
    }

    struct Agent {
        address  wallet;
        string   name;
        string   specialty;
        uint256  reputation;      // 0-100
        uint256  jobsCompleted;
        uint256  totalEarned;     // lifetime STT earned
        bool     isRegistered;
        uint256  registeredAt;
    }

    struct Bid {
        address  agent;
        uint256  bidAmount;
        string   proposal;
        uint256  estimatedTime;   // in seconds
        uint256  timestamp;
    }

    // ── Enums ─────────────────────────────────────────────────────────────────

    enum JobStatus { Open, Assigned, UnderReview, Completed, Disputed, Cancelled }

    // ── State ─────────────────────────────────────────────────────────────────

    address public owner;
    uint256 public jobCount;
    uint256 public agentCount;
    uint256 public totalVolumeSTT;
    uint256 public platformFeePercent = 2; // 2% platform fee

    mapping(uint256 => Job)        public jobs;
    mapping(address => Agent)      public agents;
    mapping(uint256 => Bid[])      public jobBids;
    mapping(address => uint256[])  public agentActiveJobs;
    mapping(address => uint256[])  public posterJobs;

    // ── Somnia Reactive State (agents auto-trigger on these changes) ──────────
    mapping(uint256 => bool)  public jobNeedsAgent;     // reactive trigger
    mapping(address => bool)  public agentAvailable;    // reactive trigger

    // ── Events ────────────────────────────────────────────────────────────────

    event JobPosted        (uint256 indexed jobId, address indexed poster, string title, uint256 reward, string category);
    event AgentRegistered  (address indexed agent, string name, string specialty);
    event BidPlaced        (uint256 indexed jobId, address indexed agent, uint256 amount);
    event JobAssigned      (uint256 indexed jobId, address indexed agent, uint256 bidAmount);
    event ResultSubmitted  (uint256 indexed jobId, address indexed agent, string ipfsHash);
    event JobCompleted     (uint256 indexed jobId, address indexed agent, uint256 reward);
    event DisputeRaised    (uint256 indexed jobId, address indexed raisedBy);
    event ReputationUpdated(address indexed agent, uint256 newReputation);

    // ── Somnia-Native: API Query Result Events ────────────────────────────────
    event AgentAPIQueryExecuted(uint256 indexed jobId, string apiUrl, bytes result);
    event AgentAIModelResult   (uint256 indexed jobId, string modelId, bytes result);

    // ── Modifiers ─────────────────────────────────────────────────────────────

    modifier onlyOwner()           { require(msg.sender == owner, "Not owner"); _; }
    modifier onlyRegistered()      { require(agents[msg.sender].isRegistered, "Not registered agent"); _; }
    modifier jobExists(uint256 id) { require(id < jobCount, "Job not found"); _; }
    modifier onlyPoster(uint256 id){ require(msg.sender == jobs[id].poster, "Not job poster"); _; }

    constructor() { owner = msg.sender; }

    // ── Agent Registry ────────────────────────────────────────────────────────

    /**
     * @notice Register as an autonomous AI agent on AgentWork / Somnia L1
     * @param _name      Agent display name
     * @param _specialty Agent's primary skill category
     */
    function registerAgent(string calldata _name, string calldata _specialty) external {
        require(!agents[msg.sender].isRegistered, "Already registered");
        require(bytes(_name).length > 0, "Name required");

        agents[msg.sender] = Agent({
            wallet:        msg.sender,
            name:          _name,
            specialty:     _specialty,
            reputation:    50,
            jobsCompleted: 0,
            totalEarned:   0,
            isRegistered:  true,
            registeredAt:  block.timestamp
        });

        // Somnia Reactive: mark agent as available — triggers reactive listeners
        agentAvailable[msg.sender] = true;
        agentCount++;

        emit AgentRegistered(msg.sender, _name, _specialty);
    }

    // ── Job Lifecycle ─────────────────────────────────────────────────────────

    /**
     * @notice Post a new job — reward locked in contract until completion
     */
    function postJob(
        string calldata _title,
        string calldata _description,
        string calldata _category,
        uint256         _deadline
    ) external payable {
        require(msg.value > 0,              "Reward required");
        require(_deadline > block.timestamp, "Deadline must be future");
        require(bytes(_title).length > 0,   "Title required");

        uint256 jobId = jobCount;
        jobs[jobId] = Job({
            id:            jobId,
            poster:        msg.sender,
            title:         _title,
            description:   _description,
            category:      _category,
            reward:        msg.value,
            deadline:      _deadline,
            assignedAgent: address(0),
            status:        JobStatus.Open,
            resultIPFS:    "",
            postedAt:      block.timestamp
        });

        posterJobs[msg.sender].push(jobId);

        // Somnia Reactive: triggers agents listening for new open jobs
        jobNeedsAgent[jobId] = true;
        jobCount++;

        emit JobPosted(jobId, msg.sender, _title, msg.value, _category);
    }

    /**
     * @notice Agent places a competitive bid on an open job
     */
    function placeBid(
        uint256         _jobId,
        uint256         _bidAmount,
        string calldata _proposal,
        uint256         _estimatedTime
    ) external onlyRegistered jobExists(_jobId) {
        Job storage job = jobs[_jobId];
        require(job.status   == JobStatus.Open,   "Job not open");
        require(block.timestamp < job.deadline,   "Deadline passed");
        require(_bidAmount   <= job.reward,       "Bid exceeds reward");
        require(msg.sender   != job.poster,       "Cannot bid own job");

        jobBids[_jobId].push(Bid({
            agent:         msg.sender,
            bidAmount:     _bidAmount,
            proposal:      _proposal,
            estimatedTime: _estimatedTime,
            timestamp:     block.timestamp
        }));

        emit BidPlaced(_jobId, msg.sender, _bidAmount);
    }

    /**
     * @notice Poster assigns job to winning agent
     */
    function assignJob(uint256 _jobId, address _agent)
        external jobExists(_jobId) onlyPoster(_jobId)
    {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open,   "Job not open");
        require(agents[_agent].isRegistered,    "Agent not registered");

        job.assignedAgent = _agent;
        job.status        = JobStatus.Assigned;

        // Somnia Reactive: remove from open job triggers
        jobNeedsAgent[_jobId]  = false;
        agentAvailable[_agent] = false;

        agentActiveJobs[_agent].push(_jobId);
        emit JobAssigned(_jobId, _agent, job.reward);
    }

    /**
     * @notice Agent submits completed work (IPFS hash of deliverable)
     */
    function submitResult(uint256 _jobId, string calldata _ipfsHash)
        external onlyRegistered jobExists(_jobId)
    {
        Job storage job = jobs[_jobId];
        require(job.assignedAgent == msg.sender,     "Not assigned agent");
        require(job.status == JobStatus.Assigned,    "Job not assigned");
        require(bytes(_ipfsHash).length > 0,         "IPFS hash required");

        job.resultIPFS = _ipfsHash;
        job.status     = JobStatus.UnderReview;

        emit ResultSubmitted(_jobId, msg.sender, _ipfsHash);
    }

    /**
     * @notice Poster approves work — releases payment to agent
     */
    function approveAndPay(uint256 _jobId)
        external jobExists(_jobId) onlyPoster(_jobId)
    {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.UnderReview, "Not under review");

        job.status = JobStatus.Completed;

        // Update agent stats
        Agent storage agent = agents[job.assignedAgent];
        agent.jobsCompleted++;
        agent.totalEarned += job.reward;
        if (agent.reputation < 98) agent.reputation += 2;
        agentAvailable[job.assignedAgent] = true;

        totalVolumeSTT += job.reward;

        // Platform fee + agent payment
        uint256 fee    = (job.reward * platformFeePercent) / 100;
        uint256 payout = job.reward - fee;
        job.reward = 0;

        payable(owner).transfer(fee);
        payable(job.assignedAgent).transfer(payout);

        emit JobCompleted(_jobId, job.assignedAgent, payout);
        emit ReputationUpdated(job.assignedAgent, agent.reputation);
    }

    // ── Somnia Agent Native Features ──────────────────────────────────────────

    /**
     * @notice Uses Somnia Agent to query a live external API on-chain
     *         Example: fetch real-time crypto price, weather data, sports scores
     *         Result is multi-validator verified — trustless oracle replacement
     */
    function queryExternalAPI(
        uint256        _jobId,
        string calldata _apiUrl
    ) external onlyRegistered jobExists(_jobId) returns (bytes memory) {
        require(jobs[_jobId].assignedAgent == msg.sender, "Not assigned");

        bytes memory result = SOMNIA_AGENT.queryAPI(
            _apiUrl,
            "GET",
            ""
        );

        emit AgentAPIQueryExecuted(_jobId, _apiUrl, result);
        return result;
    }

    /**
     * @notice Uses Somnia Agent to run an AI model on-chain
     *         Example: classify image, moderate text, audit smart contract
     *         Deterministic AI — result validated by consensus
     */
    function runAIInference(
        uint256         _jobId,
        string calldata  _modelId,
        bytes calldata   _inputData
    ) external onlyRegistered jobExists(_jobId) returns (bytes memory) {
        require(jobs[_jobId].assignedAgent == msg.sender, "Not assigned");

        bytes memory result = SOMNIA_AGENT.runAIModel(_modelId, _inputData);

        emit AgentAIModelResult(_jobId, _modelId, result);
        return result;
    }

    // ── Dispute Resolution ────────────────────────────────────────────────────

    function raiseDispute(uint256 _jobId) external jobExists(_jobId) {
        Job storage job = jobs[_jobId];
        require(
            msg.sender == job.poster || msg.sender == job.assignedAgent,
            "Not involved in job"
        );
        require(job.status == JobStatus.UnderReview, "Not under review");
        job.status = JobStatus.Disputed;
        emit DisputeRaised(_jobId, msg.sender);
    }

    function resolveDispute(uint256 _jobId, bool _payAgent)
        external onlyOwner jobExists(_jobId)
    {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Disputed, "Not disputed");

        if (_payAgent) {
            job.status = JobStatus.Completed;
            uint256 payout = job.reward;
            job.reward = 0;
            payable(job.assignedAgent).transfer(payout);
            emit JobCompleted(_jobId, job.assignedAgent, payout);
        } else {
            job.status = JobStatus.Cancelled;
            uint256 refund = job.reward;
            job.reward = 0;
            payable(job.poster).transfer(refund);
        }
    }

    // ── View Functions ────────────────────────────────────────────────────────

    function getJob(uint256 _jobId)     external view returns (Job memory)   { return jobs[_jobId]; }
    function getAgent(address _agent)   external view returns (Agent memory) { return agents[_agent]; }
    function getJobBids(uint256 _jobId) external view returns (Bid[] memory) { return jobBids[_jobId]; }
    function getPosterJobs(address _p)  external view returns (uint256[] memory) { return posterJobs[_p]; }

    function getOpenJobs() external view returns (Job[] memory) {
        uint256 count;
        for (uint256 i; i < jobCount; i++)
            if (jobs[i].status == JobStatus.Open) count++;

        Job[] memory result = new Job[](count);
        uint256 idx;
        for (uint256 i; i < jobCount; i++)
            if (jobs[i].status == JobStatus.Open) result[idx++] = jobs[i];
        return result;
    }

    function getStats() external view returns (
        uint256 _jobs, uint256 _agents, uint256 _volume
    ) {
        return (jobCount, agentCount, totalVolumeSTT);
    }
uint256 public autonomousExecutions;
uint256 public totalCompanies;
mapping(address => string) public companyNames;
event CompanyRegistered(
    address indexed owner,
    string companyName,
    uint256 timestamp
);

event AutonomousExecution(
    uint256 indexed jobId,
    address indexed agent,
    uint256 timestamp
);
function registerCompany(
    string calldata companyName
) external {
    require(bytes(companyName).length > 0, "Invalid name");

    companyNames[msg.sender] = companyName;
    totalCompanies++;

    emit CompanyRegistered(
        msg.sender,
        companyName,
        block.timestamp
    );
}

    // ── Admin ─────────────────────────────────────────────────────────────────
    function setPlatformFee(uint256 _fee) external onlyOwner {
        require(_fee <= 10, "Max 10%");
        platformFeePercent = _fee;
    }
}
function executeAutonomousTask(
    uint256 jobId
) external {
    require(
        jobs[jobId].assignedAgent != address(0),
        "No agent assigned"
    );

    autonomousExecutions++;

    emit AutonomousExecution(
        jobId,
        jobs[jobId].assignedAgent,
        block.timestamp
    );
}
function getStats() external view returns (
    uint256 _jobs,
    uint256 _agents,
    uint256 _volume
)
{
    return (
        jobCount,
        agentCount,
        totalVolumeSTT
    );
}
function getStats() external view returns (
    uint256 _jobs,
    uint256 _agents,
    uint256 _volume,
    uint256 _companies,
    uint256 _autonomous
)
{
    return (
        jobCount,
        agentCount,
        totalVolumeSTT,
        totalCompanies,
        autonomousExecutions
    );
}
