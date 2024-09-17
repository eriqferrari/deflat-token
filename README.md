
This contract implements a sophisticated deflationary token mechanism designed 
to reduce the circulating supply of tokens over time, while encouraging active 
participation from users. Every time a transfer occurs, a specific percentage 
of the tokens involved is calculated as the "burn amount." This percentage is not 
referred to as a tax, but rather as a mechanism to reserve tokens for burning.

Importantly, no percentage of tokens is deducted directly from transactions. Instead, 
the burn percentage is pre-allocated within the contract. The only action allowed 
by users is to burn tokens. This ensures that the burning process is separate from 
the transaction mechanism, with tokens being burned based on the total allocated 
amount rather than being deducted in real-time.

The burn percentage is determined dynamically using a deflation formula. This formula 
adjusts based on the current token supply, starting at a higher rate (up to 2%) and 
gradually decreasing as the total supply diminishes, eventually reaching a minimum 
rate of 0.01%. This ensures a deflationary trend while preventing the supply from 
being fully depleted.

The calculated burn amounts are stored and tracked for each user. Actual burning 
of tokens occurs through a public function called 'deflat'. Users can call this 
function to burn an amount equal to the total sum of tokens they have contributed 
to the deflation mechanism during previous transactions.

To gamify this process and incentivize user engagement, the contract uses two 
mappings:
1. `DEFLATERS`: This mapping tracks the total amount of tokens that each user has 
   contributed to the deflation pool through calculated burn percentages in their 
   transfers.
2. `BURNERS`: This mapping records how many tokens each user has successfully 
   burned by calling the 'deflat' function. Users are encouraged to participate 
   actively, adding a competitive element and rewarding the most involved participants.

This system creates a gradual, yet consistent, deflationary effect on the token 
supply, ensuring long-term value preservation. The gamified approach engages users 
and promotes scarcity, enhancing the value for all holders.

The DEFLAT token is created to promote the adoption of a new fungible token standard
that includes a public burn function for all compliant tokens.
