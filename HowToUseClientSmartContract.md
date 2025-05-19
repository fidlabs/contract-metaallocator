# How to Use the Client Smart Contract for Allocators

This guide explains how allocators can use the Client Smart Contract to allocate DataCap to clients.

## 1. Initial Setup

To begin using the Client Smart Contract, allocators must select **Allocation Type: Contract** during the **first allocation** to a client.
![Screenshot from 2025-05-15 19-48-34](https://github.com/user-attachments/assets/7710674a-3ccb-4413-9415-ca17e8a3e9a7)


## 2. Granting DataCap to a Client via the Smart Contract

Granting DataCap through the Client Smart Contract requires **two transactions**, both of which **must be signed by the allocator**:

1. **Transfer DataCap to the Smart Contract**  
   The allocator sends the DataCap amount to the Client Smart Contract address.

2. **Increase Client’s Available DataCap**  
   The allocator calls the contract function to increase the available DataCap for the specified client.

## 3. Configuring Storage Providers

Using the Client Smart Contract requires specifying the **storage providers (SPs)** that the client will interact with.  
The frontend accepts SP IDs in two formats:
- `f01234567`
- `1234567`

Additionally, the **max deviation** is currently set to **10%**, but this value will be configurable in the future.  
A transaction that sets this value is automatically triggered during the initial configuration of the storage providers.

## 4. Notify the client about the use of Client Smart Contract

Leave a comment on the GitHub issue associated with the client, informing them that they are using a Client Smart Contract. Include the address of the contract in your message.  
To find the contract address:

1. Go to [Allocator JSON files](https://github.com/filecoin-project/Allocator-Registry/tree/main/Allocators).
2. Locate your corresponding JSON file.
3. Open the file and copy the value from the `client_contract_address` field.
4. Post a comment on the related GitHub issue with the following information:

   - Inform the client that their allocation is now using a Client Smart Contract.
   - Include the contract address you copied.


## What Is Max Deviation?

The **Maximum Deviation** defines how much more storage a single Storage Provider (SP) can receive compared to an equal distribution among all selected SPs.

It is currently set to **10% of the client’s total allocation** and is enforced via a smart contract, which is automatically triggered during the initial setup of storage providers.

### Example Interpretation

Let’s assume the client is allocating a total of **100 TiB** across **5 SPs**.

- The **equal share** per SP would be:  
  `100 TiB ÷ 5 = 20 TiB`

- With a **maximum deviation of 10%**, an individual SP can receive up to **10 TiB extra** (10% of the total allocation).

- This means the **maximum amount a single SP can receive** is:  
  `20 TiB (equal share) + 10 TiB (deviation) = 30 TiB`

This mechanism prevents over-concentration of deals on a single SP while still allowing some flexibility.

---

# How to Use the Client Smart Contract for Clients

1. To see the current DataCap usage, please visit [Allocator.tech](https://allocator.tech) and find your application, where a progress bar displays the DataCap consumed by the client in their latest allocation.

![DataaCap used from most recent allocation](https://github.com/user-attachments/assets/b0b3b215-d9b3-4ff3-a238-969f23bd0a70)

2. The allocation will not be visible on the personal address because it is currently associated with the contract address. If you want to validate your claims go to [datacapstats.io/clients](https://datacapstats.io/clients) and search for the client, which in this case is the contract.
To check the address of the contract assigned to you, go to your allocator's bookkeeping repo. In the Applications folder, find the JSON file of your application by your address, and check the value of the Client Contract Address field.


This step-by-step guide explains how to create verified DDO deals using DataCap granted through a Client Smart Contract with Boost.
---

## How to onboard data using DDO deals

1.  First, you need to initialise a new Boost client and also set the endpoint for a public Filecoin node. In this example we are using [https://glif.io](https://glif.io/)


    ```
    export FULLNODE_API_INFO=https://api.node.glif.io

    boost init
    ```


2.  The `init` command will output your new wallet address, and warn you that the market actor is not initialised.



    ```
    boost init

    boost/init_cmd.go:53    default wallet set      {"wallet": "f3wfbcudimjcqtfztfhoskgls5gmkfx3kb2ubpycgo7a2ru77temduoj2ottwzlxbrbzm4jycrtu45deawbluq"}
    boost/init_cmd.go:60    wallet balance  {"value": "0"}
    boost/init_cmd.go:65    market actor is not initialised, you must add funds to it in order to send online deals
    ```


3.  Now, you need to send some funds and Datacap to the wallet.


4.  You can confirm that the market actor has funds and Datacap by running `boost wallet list`.

    After that you need to generate a `car` file for data you want to store on Filecoin, and note down its `payload-cid.` We recommend using [`go-car`](https://github.com/ipld/go-car/releases/latest) CLI to generate the car file.



    ```
    boostx generate-rand-car -c=50 -l=$links -s=5120000 .
    Payload CID: bafykbzacedr7avw5yvxgjftkhfgzgbinq523csw3ir5hyukx2ulewaigyjdrm, written to: <$CWD>/bafykbzacedr7avw5yvxgjftkhfgzgbinq523csw3ir5hyukx2ulewaigyjdrm.car
    ```


5.  Then you need to calculate the `commp` and `piece size` for the generated `car` file:
    
    `boostx generate-rand-car -c=50 -l=$links -s=5120000`

    ```
    boostx commp bafykbzacedr7avw5yvxgjftkhfgzgbinq523csw3ir5hyukx2ulewaigyjdrm.car

    CommP CID:  baga6ea4seaqjpldhlgodxw2vjj6g46xra7jthe2g37kt7577ep5euxipkupfsly
    Piece size:  8388608
    Car file size:  7657847
    ```


6.  Create a new verified allocation for this piece using the boost client. You can use other methods to create allocations as long as the piece details match the generated commP. If you received DataCap via a Client Smart Contract, be sure to include the `--evm-client-contract` option, and provide the proper value when creating the allocation.
To check the address of the contract assigned to you, first check the associated GitHub issue. The address should be provided as a comment in the issue by the allocator. If the address is not available there, go to your allocator's bookkeeping repo. In the Applications folder, find the JSON file of your application by your address, and check the value of the Client Contract Address field.
    ```
    boost allocate 
    --evm-client-contract f410foc6psy3k7a2fb37tb2tslxj2hvzuj5ymcku7xia --miner=t01013 --piece-info=baga6ea4seaqjpldhlgodxw2vjj6g46xra7jthe2g37kt7577ep5euxipkupfsly=8388608 --wallet t3tejq3lb3szsq7spvttqohsfpsju2jof2dbive2qujgz2idqaj2etuolzgbmro3owsmpuebmoghwxgt6ricvq

    about to send message with the following gas costs
    max fee:      0.00000000512550864 FIL (absolute maximum amount you are willing to pay to get your transaction confirmed)
    gas fee cap:  0.00000000000000012 FIL
    gas limit:    42712572
    gas premium:  0.000000000000000023 FIL
    basefee:      0.0000000000000001 FIL

    Proceed? Yes [y] / No [n]:
    y
    2024-03-11T18:11:59.794Z	INFO	boost	boost/direct_deal.go:112	submitted data cap allocation message	{"cid": "bafy2bzacecyxmx4uyuqfy6xdnlaba2aamlghcujt2asvqmkz6trilnttcouoi"}
    2024-03-11T18:11:59.794Z	INFO	boost	boost/direct_deal.go:113	waiting for message to be included in a block

    AllocationID  Client  Miner  PieceCid                                                          PieceSize  TermMin  TermMax Expiration  
    31825         1011    1013   baga6ea4seaqjpldhlgodxw2vjj6g46xra7jthe2g37kt7577ep5euxipkupfsly  8388608    518400   5256000  1601277
    ```


7.  Import the piece for the newly create allocation using `boostd`. Remember that `--client-addr` must be equal to the address of the Client Smart Contract.
    ```
    boostd import-direct --client-addr=f410foc6psy3k7a2fb37tb2tslxj2hvzuj5ymcku7xia --allocation-id=31825 baga6ea4seaqjpldhlgodxw2vjj6g46xra7jthe2g37kt7577ep5euxipkupfsly ~/bafykbzacedr7avw5yvxgjftkhfgzgbinq523csw3ir5hyukx2ulewaigyjdrm.car

    Direct data import scheduled for execution
    ```


8. Watch the `boostd` UI to verify that the new DDO deal reaches "Complete" and "Claim Verified" state.
