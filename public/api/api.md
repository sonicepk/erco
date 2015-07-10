FORMAT: 1A

# Erco API documentation

[Back to Erco](..)

# Group Subnet

#### Attributes

+ **id** `number`  
  internal id of the subnet. Changes every time Erco is reloaded
+ **cidr** `string`  
  CIDR notation of the subnet
+ **next_hop** `string`  
  IP address of the next hop
+ **communities** `array[string]`  
  Array of communities is announced with
+ **created_at** `number`  
  UNIX timestamp of the subnet's creation
+ **human_created_at** `string`  
  human readable representation of `created_at`
+ **modified_at** `number`  
  UNIX timestamp of the subnet's last modification
+ **human_modified_at** `string`  
  human readable representation of `modified_at`

# /api/subnet

## GET

Get the list of the announced subnets.

+ Response 200 (application/json)

        [
            {
                "id":1,
                "cidr":"203.0.113.0/24",
                "next_hop":"192.0.2.42",
                "communities":
                    [
                        "64496:42"
                    ],
                "created_at":1433497409,
                "human_created_at":"Fri, 05 Jun 2015 09:43:29 GMT",
                "modified_at":null,
                "human_modified_at":null
            },{
                "id":2,
                "cidr":"198.51.100.42\/32",
                "next_hop":"192.0.2.44",
                "communities":
                    [
                        "64496:42",
                        "64511:1337"
                    ],
                "created_at":1433497409,
                "human_created_at":"Fri, 05 Jun 2015 09:43:29 GMT",
                "modified_at":1435832156,
                "human_modified_at":"Thu, 02 Jul 2015 10:15:55 GMT"
            }
        ]

## POST

Announce a new subnet.

+ Request (application/x-www-form-urlencoded)

        cidr=198.51.100.43/32&next_hop=192.0.2.42&communities[]=64496:42&communities[]=64511:1337

+ Response 200 (application/json)

        # Success:
        {
            "success":true,
            "msg":{
                "id":3,
                "cidr":"198.51.100.43\/32"
                "next_hop":"192.0.2.42",
                "communities":
                    [
                        "64496:42",
                        "64511:1337"
                    ],
                "created_at":1433497409,
                "human_created_at":"Fri, 05 Jun 2015 09:43:29 GMT",
                "modified_at":null,
                "human_modified_at":null
            }
        }

        # Failure:
        {
            "success":false,
            "msg":"The reason why it failed"
        }

## PUT

Modified an announced subnet.

+ Request (application/x-www-form-urlencoded)

        id=3&cidr=198.51.100.1/32&next_hop=192.0.2.42&communities[]=64496:42&communities[]=64511:123

+ Response 200 (application/json)

        # Success:
        {
            "success":true,
            "msg":{
                "id":3,
                "cidr":"198.51.100.1\/32"
                "next_hop":"192.0.2.42",
                "communities":
                    [
                        "64496:42",
                        "64511:123"
                    ],
                "created_at":1433497409,
                "human_created_at":"Fri, 05 Jun 2015 09:43:29 GMT",
                "modified_at":1435832156,
                "human_modified_at":"Thu, 02 Jul 2015 10:15:55 GMT"
            }
        }

        # Failure:
        {
            "success":false,
            "msg":"The reason why it failed"
        }

## DELETE

Stop to announce a subnet.

+ Request (application/x-www-form-urlencoded)

        id=3

+ Response 200 (application/json)

        # Success:
        {
            "success":true,
            "msg":"Network successfully deleted."
        }

        # Failure:
        {
            "success":false,
            "msg":"The reason why it failed"
        }

# Group Exabgp

## GET /api/exabgp/status

Get the status of Exabgp (running, not running).

+ Response 200 (application/json)

        {
            "running":true,
            "file_missing":false
        }

## GET /api/exabgp/command{?action}

Execute a command on Exabgp.

+ Parameters
    + action: `reload` (string, required) - The available commands depends of your configuration

+ Response 200 (application/json)

        # Success:
        {
            "success":true,
            "msg":"Exabgp has been successfully reloaded."
        }

        # Failure:
        {
            "success":false,
            "msg":"The reason why it failed"
        }

## GET /api/exabgp/commands

Get the list of available commands.

+ Response 200 (application/json)

        [
            "reload"
        ]

# Group Communities

# /api/communities

## GET

Get the list of available communities.

+ Response 200 (application/json)

        {
            "64496:42":"Foo",
            "64511:1337":"Bar",
            "64511:123":"Baz",
        }

# Group Next hops

# /api/next_hops

## GET

Get the list of available next hops.

+ Response 200 (application/json)

        {
            "192.0.2.42":"Alice",
            "192.0.2.44":"Bob"
        }

