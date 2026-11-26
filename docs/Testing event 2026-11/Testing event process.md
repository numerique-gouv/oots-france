# Testing event process

I need to upload headers & body (regrep) of each request of a successful transaction with another country.
Then the European commission will test their validity (each individually, then as a whole) and give us feedback.

## The naming convention

Source: slide 40 of the M58 meeting deck, `(SDG OOTS).(TD SG M58).(03112026).pdf`.

Pattern: `<MS1><MS2>-<TC>-<run>_<fileType>.xml`, with no spaces.

- `MS1`: country code of the Evidence Requester. `MS2`: country code of the Evidence Provider.
- `TC`: the test case, here `TC06`.
- `run`: two digits, `01`, then `02` for a rerun.
- `fileType`: what the file contains (see below).

TC06 is run in both directions, so there are two prefixes: `FRBE-TC06-01` (France requests, Belgium provides) and `BEFR-TC06-01` (Belgium requests, France provides).

File types, for exchanges with preview (8 files per run):

| Message | ebMS header | RegRep body |
| --- | --- | --- |
| Request 1 | `HReq1` | `EvReq1` |
| Response 1 (preview required) | `HRes1` | `EvRes1` |
| Request 2 (after reauthentication) | `HReq2` | `EvReq2` |
| Response 2 (the evidence) | `HRes2` | `EvRes2` |

The Common Services responses come from the requester only, and only for the queries it actually made: `EB1Res`, `EB2Res`, `DSDRes`.

Examples: `FRBE-TC06-01_HReq1.xml`, `FRBE-TC06-01_EvRes2.xml`, `FRBE-TC06-01_DSDRes.xml`.

Report: one per run, shared between requester and provider, named `<Test ID>_Report.xlsx`, e.g. `FRBE-TC06-01_Report.xlsx`.

## The messages files

I think I will not give the common services messages because I don't store them yet, and I've been told they are optional.

## Upload results

Results : The xml files & test execution report spreadsheet (BEFR_TC06-01_Report_TEST.xlsx).

Publish results in https://eceuropaeu.sharepoint.com/:f:/r/teams/GRP-SDGOOTSImplementersspace/Shared%20Documents/OOTS%20Checkpoint%20-%20General%20channel/Testing%20track/Test%20executions/To%20be%20checked?d=w9c31470e7bf6438aa23b35862d872294&csf=1&web=1&e=ltAotb
 
## Testing ourselves

We can also test ourselves in https://oots-testing-acc-ag.westeurope.cloudapp.azure.com/