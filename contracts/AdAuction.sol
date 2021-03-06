// inspired by https://solidity.readthedocs.io/en/develop/solidity-by-example.html
pragma solidity ^0.4.21;

contract AuctionList {
    AdAuction[] public auctions;

    function AuctionList() public { }

    event NewAuction(uint id);

    function new_auction(
        uint bidding_end,
        address beneficiary,
        string name,
        string description,
        string email,
        string tags,
        string profile
    ) public {
        auctions.push(new AdAuction(bidding_end, beneficiary, name, description, email, tags, profile));
        emit NewAuction(auctions.length - 1);
    }
}

contract AdAuction {
    // Parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.
    address public beneficiary;
    uint public bidding_end;
    string public name;
    string public description;
    string public email;
    string public tags;
    string public profile;

    struct Bid {
        uint id;
        uint value;
        address owner;
        string name;
        string email;
    }

    // Storage for all bids
    Bid[] bids;

    // Allowed withdrawals of previous bids
    mapping(address => uint) public pending_returns;

    // Set to true at the end, disallows any change
    bool public ended;

    // Events that will be fired on changes.
    event NewBid(uint bid_id);
    event AuctionEnded(uint winner_id);
    event WithdrawAvailable(address owner, uint value);

    function get_bid_value(uint _id) public returns (uint) {
        return bids[_id].value;
    }
    function get_bid_owner(uint _id) public returns (address) {
        return bids[_id].owner;
    }
    function get_bid_name(uint _id) public returns (string) {
        return bids[_id].name;
    }
    function get_bid_email(uint _id) public returns (string) {
        return bids[_id].email;
    }
    function num_bids() public returns (uint) {
        return bids.length;
    }

    // The following is a so-called natspec comment,
    // recognizable by the three slashes.
    // It will be shown when the user is asked to
    // confirm a transaction.

    /// Create a simple auction with `_bidding_end`
    /// seconds bidding time on behalf of the
    /// beneficiary address `_beneficiary`.
    function AdAuction(
        uint _bidding_end,
        address _beneficiary,
        string _name,
        string _description,
        string _email,
        string _tags,
        string _profile
    ) public {
        beneficiary = _beneficiary;
        bidding_end = _bidding_end;
        name = _name;
        description = _description;
        email = _email;
        tags = _tags;
        profile = _profile;
    }

    /// Bid on the auction with the value sent
    /// together with this transaction.
    /// The value will only be refunded if the
    /// auction is not won.
    function bid(string _name, string _email) public payable {
        // No arguments are necessary, all
        // information is already part of
        // the transaction. The keyword payable
        // is required for the function to
        // be able to receive Ether.

        // Revert the call if the bidding
        // period is over.
        require(now <= bidding_end);
        require(!ended);
        require(msg.sender != beneficiary);

        Bid memory it = Bid(
            bids.length,
            msg.value,
            msg.sender,
            _name,
            _email
        );
        bids.push(it);
        emit NewBid(it.id);
    }

    /// Withdraw a bid that not accepted.
    function withdraw() public returns (bool) {
        require(now > bidding_end);
        require(ended);

        uint amount = pending_returns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `send` returns.
            pending_returns[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                // No need to call throw here, just reset the amount owing
                pending_returns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function select(uint bid_id) public {
        require(now >= bidding_end); // auction did not yet end
        require(!ended); // this function has already been called
        require(msg.sender == beneficiary); // only beneficiary can select a bid

        ended = true;
        Bid storage it = bids[bid_id];
        for (uint i = 0; i < bids.length; i++) {
            if (i != bid_id) {
                pending_returns[bids[i].owner] = bids[i].value;
                emit WithdrawAvailable(bids[i].owner, bids[i].value);
            }
        }
        pending_returns[beneficiary] = it.value;
        emit WithdrawAvailable(beneficiary, it.value);
        emit AuctionEnded(it.id);
    }
}
