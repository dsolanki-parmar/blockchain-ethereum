pragma solidity ^0.5.9;

contract KYC{

   address private admin;
   uint nBanks;

   // modifier to check if caller is admin
    modifier isAdmin() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == admin, "Caller is not admin");
        _;
    }

    modifier isBankAllowedtoVote() {
        require(banks[msg.sender].isAllowedToVote == true, "Bank is not allowed to vote");
        _;
    }
    constructor() public {
        admin = msg.sender; // 'msg.sender' is sender of current call
        nBanks = 0;
    }

   struct KycRequest {
        string userName;
        string data;
        address bank;
   }

    struct Customer {
        string userName;
        string data;
        address bank;
        bool kycStatus;
        uint upVote;
        uint downVote;
    }

    struct Bank {
        string name;
        address ethAddress;
        string regNumber;
        bool isAllowedToVote;
        uint complaintsReported;
        uint KYC_count;
    }

    mapping(string => Customer) customers;

    mapping(address => Bank) banks;
    mapping(string => KycRequest) kyc_docs;

    function addCustomer(string memory _userName, string memory _customerData) public {
        /*
        This function will add a customer to the customer list.
        Validation :
        when adding a customer to the customer list, make sure that the customer is not already present
        in the customer list. If the customer is already present, then reject the request.
        */
        require(customers[_userName].bank == address(0), "Customer is already present, please call modifyCustomer to edit the customer data");
        customers[_userName].userName = _userName;
        customers[_userName].data = _customerData;
        customers[_userName].bank = msg.sender;
        customers[_userName].upVote = 0;
        customers[_userName].downVote = 0;
        customers[_userName].kycStatus = false;
        addRequest(_userName, _customerData);
    }

    function viewCustomer(string memory _userName) public view returns (string memory, string memory, address) {
        /*
        This function allows a bank to view the details of a customer.
        */
        require(customers[_userName].bank != address(0), "Customer is not present in the database");
        return (customers[_userName].userName, customers[_userName].data, customers[_userName].bank);
    }

    function modifyCustomer(string memory _userName, string memory _newcustomerData) public {
        /*
           This function allows a bank to modify a customer's data.
           This will remove the customer from the KYC request list and set the number of downvotes and upvotes to zero.
        */
        require(customers[_userName].bank != address(0), "Customer is not present in the database");
        customers[_userName].data = _newcustomerData;
        removeRequest(_userName);
        customers[_userName].upVote = 0;
        customers[_userName].downVote = 0;
        customers[_userName].kycStatus = false;
    }

    function addRequest(string memory _userName, string memory _customerData) public{
        /*
        This function is used to add the KYC request to the requests list.
        */
        require(kyc_docs[_userName].bank == address(0), "KYC doc already present");
        require(customers[_userName].bank != address(0), "Customer is not present in the database");
        kyc_docs[_userName].userName = _userName;
        kyc_docs[_userName].data = _customerData;
        kyc_docs[_userName].bank = msg.sender;
        banks[msg.sender].KYC_count++;
    }
    function removeRequest(string memory  _userName) public {
        /*
        This function will remove the request from the requests list
        */

          require(kyc_docs[_userName].bank != address(0), "KYC doc is not present");
          delete kyc_docs[_userName];

    }
    function upVote(string memory _userName)  public isBankAllowedtoVote {
        /*
           This function allows a bank to cast an upvote for a customer.
           Validation : Check if bank is allowed to Vote
        */
        require(customers[_userName].bank != address(0), "Customer is not present in the database");
        customers[_userName].upVote++;
        if (customers[_userName].upVote > customers[_userName].downVote) {
          if (customers[_userName].downVote > nBanks/3) {
              customers[_userName].kycStatus = false;
          }
        else {
              customers[_userName].kycStatus = true;
        }

        }
        else {
             customers[_userName].kycStatus = false;
        }
    }

    function downvote(string memory _userName) public isBankAllowedtoVote {
        /*  This function allows a bank to cast a downvote for a customer.
         This vote from a bank means that it does not accept the customer details.
      o	Parameter - Customer name as a string
       Validation : Check if bank is allowed to Vote
       */
         require(customers[_userName].bank != address(0), "Customer is not present in the database");
         customers[_userName].downVote++;
    }

     function getBankComplaints(address _bank) public view returns (uint complaintsReported) {
         /*
         This function is used to fetch bank complaints from the smart contract.
         */

         require(banks[_bank].ethAddress != address(0), "Bank is not present in the database");
         return banks[_bank].complaintsReported;

     }

      function viewBankDetails(address _bank) public view returns (string memory) {
          /*
          This function is used to fetch the bank details.
          */
        require(banks[_bank].ethAddress != address(0), "Bank is not present in the database");
        return (banks[_bank].name);

     }
      function reportBank(address _bank) public  {
          /*
          This function is used to report a complaint against any bank in the network.
          */
       require(banks[_bank].ethAddress != address(0), "Bank is not present in the database");
       banks[_bank].complaintsReported++;


      }

     function addBank(string memory _bankName, address _bank, string memory _regNo) public isAdmin {
         /* This function is used by the admin to add a bank to the KYC Contract.
         Validation: You need to verify whether the user trying to call this function is the admin or not.
         */
          require(banks[_bank].ethAddress == address(0), "Bank is already present");
          banks[_bank].ethAddress = _bank;
          banks[_bank].name = _bankName;
          banks[_bank].regNumber = _regNo;
          banks[_bank].isAllowedToVote = true;
          banks[_bank].complaintsReported = 0;
          nBanks++;

     }

     function banBank(address _bank) public isAdmin {
         /*
           Called by Admin to ban the bank If more than one-third of the total banks in the network complain against a certain bank
         */
       if (nBanks/3 < banks[_bank].complaintsReported) {
           modifyBank(_bank, false);
       }
     }
      function modifyBank(address _bank, bool _val) public isAdmin {
          /*
            This function can only be used by the admin to change the status of isAllowedToVote
            of any of the banks at any point in time.
             Validation: You need to verify whether the user trying to call this function is the admin or not.
          */
        require(banks[_bank].ethAddress != address(0), "Bank is not present in the database");
        banks[_bank].isAllowedToVote = _val;

      }
      function removeBank(address _bank) public isAdmin{
          /*
          This function is used by the admin to remove a bank from the KYC Contract.
           Validation: You need to verify whether the user trying to call this function is the admin or not.
          */
           require(banks[_bank].ethAddress != address(0), "Bank is not present in the database");
           delete banks[_bank];
           nBanks--;
      }

}
