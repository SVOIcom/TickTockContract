pragma ton-solidity ^ 0.39.0;

pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

/*
    .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------. 
    | .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
    | |    _______   | || | ____   ____  | || |     ____     | || |     _____    | || |              | || |  ________    | || |  _________   | || | ____   ____  | |
    | |   /  ___  |  | || ||_  _| |_  _| | || |   .'    `.   | || |    |_   _|   | || |              | || | |_   ___ `.  | || | |_   ___  |  | || ||_  _| |_  _| | |
    | |  |  (__ \_|  | || |  \ \   / /   | || |  /  .--.  \  | || |      | |     | || |              | || |   | |   `. \ | || |   | |_  \_|  | || |  \ \   / /   | |
    | |   '.___`-.   | || |   \ \ / /    | || |  | |    | |  | || |      | |     | || |              | || |   | |    | | | || |   |  _|  _   | || |   \ \ / /    | |
    | |  |`\____) |  | || |    \ ' /     | || |  \  `--'  /  | || |     _| |_    | || |      _       | || |  _| |___.' / | || |  _| |___/ |  | || |    \ ' /     | |
    | |  |_______.'  | || |     \_/      | || |   `.____.'   | || |    |_____|   | || |     (_)      | || | |________.'  | || | |_________|  | || |     \_/      | |
    | |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | |
    | '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
    '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------' 
*/

import "./interfaces/ISleepyContractInterface.sol";


// Structure that holds wake up info
struct WakeUpStruct {
        address contractToPing;
        TvmCell functionParameters;
}



// Contract that will wake up other contracts
contract TickTockContract {

    // Owner pubkey
    uint256 _ownerPubkey;

    // Value that defines if function must be called on tick or tock
    bool TICK_TOCK;

    // Minimum delta in time from request to add contract to shedule
    uint256 MINIMUM_DELTA;

    // Map to store wake up info
    mapping(uint256 => mapping(uint8 => WakeUpStruct)) wakeUpShedule;

    // Exception codes
    uint constant INCORRECT_TIME_TO_WAKE_UP  = 101; // At call time no contracts can be waked up
    uint constant TOO_LATE_TO_ADD_IN_SHEDULE = 102; // Too late to add contract to shedule
    uint constant UNAUTHORIZED_ACCESS        = 103; // Someone tried to call fucntions with onlyOwner modifier
    uint constant QUEUE_FULL                 = 104; // Queue to wake up for chosen time is full

    constructor(
        bool tickTockState, 
        uint256 minDelta
    )
        public
    {
        tvm.accept();
        _ownerPubkey = msg.pubkey();
        TICK_TOCK = tickTockState;
        MINIMUM_DELTA = minDelta;
    }

    // This modifier is used when only owner of contract can call function
    modifier onlyOwner {
        require(msg.pubkey() == _ownerPubkey, UNAUTHORIZED_ACCESS);
        tvm.accept();
        _;
    }

    // Change tick or tock state
    // If set to false, contract will wake contracts up on tick transactions
    // If set to true, contract will wake contracts up on tock transactions
    function changeTickTock(bool tickOrTock) 
        onlyOwner
        external
    {
        TICK_TOCK = tickOrTock;
    }

    // Change minimum delta in time
    // This is used as threshold
    // Contracts can not be added if current block time + time delta 
    // is bigger than time of planned contract wake up 
    function changeMinimumDelta(uint256 newDelta)
        onlyOwner
        external
    {
        MINIMUM_DELTA = newDelta;
    }

    // Get tick/tock state
    function getTickTockState()
        public
        view
        responsible
        returns (bool)
    {
        tvm.accept();
        return TICK_TOCK;
    }

    // Get minimum delta in time
    function getMinimumDelta()
        public
        view
        responsible
        returns (uint256)
    {
        tvm.accept();
        return MINIMUM_DELTA;
    }

    // This function wakes up contract
    function _wakeUpContract(WakeUpStruct contractToWakeUp) internal {
        ISleepyContract(contractToWakeUp.contractToPing).wakeMeUp(contractToWakeUp.functionParameters);
    }

    // This function must be used in order to check
    // If there are any free space left for specified time to wake up
    // For specified time there can be only 256 contracts to wake up
    // This function returns uint16 because 256 exceeds uint8 range
    function timeQueueLen(uint256 time) 
        public
        view
        responsible
        returns (uint16)
    {
        tvm.accept();
        mapping(uint8 => WakeUpStruct) contractQueue = wakeUpShedule[time];
        if (!contractQueue.empty()) {
            optional(uint8, WakeUpStruct) maxVal = contractQueue.max();

            if (maxVal.hasValue()) {
                (uint8 maxLen,) = maxVal.get();
                maxLen += 1;
                return 256 - maxLen;
            } else {
                return 256;
            }
        }

        return 256;
    }

    // Function that will be called on tick or tock transaction
    // It implements contract wake up logic
    onTickTock(bool isTock) external {
        // Check if the cycle is right
        require(isTock == TICK_TOCK, INCORRECT_TIME_TO_WAKE_UP);
        tvm.accept();

        // Check if it is time to wake up contracts
        optional(uint256, mapping(uint8 => WakeUpStruct)) closestToWakeUp = wakeUpShedule.min();
        while (closestToWakeUp.hasValue()) {
            (uint time,) = closestToWakeUp.get();
            // If it is not time yet then exit
            if (now > time)
                break;
            
            // If it is time to wake up contracts then start to wake up contracts
            (,mapping(uint8 => WakeUpStruct) contractsToWakeUp) = closestToWakeUp.get();
            optional(uint8, WakeUpStruct) contractWakeUpInfo = contractsToWakeUp.min();
            // While there are contracts left to wake up, wake them up
            while (contractWakeUpInfo.hasValue()) {
                (uint8 contractId, WakeUpStruct contractCallInfo) = contractWakeUpInfo.get();
                _wakeUpContract(contractCallInfo);
                contractsToWakeUp.delMin();
                if (!contractsToWakeUp.empty())
                    contractWakeUpInfo = contractsToWakeUp.min();
                else
                    break;
            }

            // Contracts that are required to wake up were pinged so we delete them from shedule
            wakeUpShedule.delMin();
            // Get the next possible contract group to wake up
            if (!wakeUpShedule.empty())
                closestToWakeUp = wakeUpShedule.min();
            else
                break;
        }
    }

    // Function to add contract to shedule
    function addContractToShedule(
        address contractAddress, 
        uint256 timeToWakeUp, 
        TvmCell callParameters
    )
        external
    {
        // Time requirements
        require(timeToWakeUp >= uint256(now + MINIMUM_DELTA), TOO_LATE_TO_ADD_IN_SHEDULE);
        tvm.accept();

        // Check if queue for chosen time exists, if not - initialize it
        if (wakeUpShedule[timeToWakeUp].empty()) {
            wakeUpShedule[timeToWakeUp][0] = WakeUpStruct(contractAddress, callParameters);
        } else {
            // If queue already exists - check if it is not yet filled
            mapping(uint8 => WakeUpStruct) contractGroup = wakeUpShedule[timeToWakeUp];
            optional(uint8, WakeUpStruct) lastContract = contractGroup.max();
            if (lastContract.hasValue()) {
                // Check if queue is already full
                (uint8 maxId,) = lastContract.get();
                require(maxId < 255, QUEUE_FULL);
                maxId += 1;
                // If queue is not filled yet then add contract to wake up shedule\
                wakeUpShedule[timeToWakeUp][maxId] = WakeUpStruct(contractAddress, callParameters);
            }
        }
    }
}
