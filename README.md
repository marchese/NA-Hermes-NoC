# Hermes-NoC
This project proposes a network adapter to the Hermes-NoC. The network adapter enables "Whishbone" peripherals to be connected to the network. In order to translate the internal communication protocol of the network (credit-based rx/tx) to wishbone and vise-versa the adapter must be placed in between an external peripheral and a border-node of the network, thus interposing all the communication between them.

**Use the following commands to start the simulation.**

  `cd proj`

  `vsim -do simulate.do`
