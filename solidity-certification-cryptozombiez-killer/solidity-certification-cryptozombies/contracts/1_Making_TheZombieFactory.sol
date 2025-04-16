 // First day of Solidity: I learn about basic syntax of solidity

 // I learn about version control using fragma
 // I learn about contract which input every function, struct, etc for the smart contract
 // I learn about variables which is uint = uint256
 // I learn about struct and its use for storing data and set new data type in a construct
 // I learn about array syntax[]
 // I learn about function which can be public or private and it can returns with view (Iterate each function and store it in state of blockchain and it cost 0 ETH gas fees, think of it like you reading a book. Last but not least is, pure (which only iterate based on the function like think simple math out of the box)


pragma solidity  >=0.5.0 <0.6.0;

contract ZombieFactory {

    uint dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;

    struct Zombie {
        string name;
        uint dna;
    }

    Zombie[] public zombies;

    function _createZombie(string memory _name, uint _dna) private {
        zombies.push(Zombie(_name, _dna));
    }

    function _generateRandomDna(string memory _str) private view returns (uint) {
        uint rand = uint(keccak256(abi.encodePacked(_str)));
        return rand % dnaModulus;
    }
    
    // start here

}
