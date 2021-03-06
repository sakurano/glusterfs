#!/bin/bash

. $(dirname $0)/../../include.rc
. $(dirname $0)/../../cluster.rc
. $(dirname $0)/../../volume.rc

function rebalance_status_field_1 {
        $CLI_1 volume rebalance $1 status | awk '{print $7}' | sed -n 3p
}

cleanup;
TEST launch_cluster 2;
TEST $CLI_1 peer probe $H2;

EXPECT_WITHIN $PROBE_TIMEOUT 1 peer_count

$CLI_1 volume create $V0 $H1:$B1/$V0  $H2:$B2/$V0
EXPECT 'Created' cluster_volinfo_field 1 $V0 'Status';

$CLI_1 volume start $V0
EXPECT 'Started' cluster_volinfo_field 1 $V0 'Status';

#bug-1231437

#Mount FUSE
TEST glusterfs -s $H1 --volfile-id=$V0 $M0;

TEST mkdir $M0/dir{1..4};
TEST touch $M0/dir{1..4}/files{1..4};

TEST $CLI_1 volume add-brick $V0 $H1:$B1/${V0}1 $H2:$B2/${V0}1

TEST $CLI_1 volume rebalance $V0  start
EXPECT_WITHIN $REBALANCE_TIMEOUT "completed" cluster_rebalance_status_field 1  $V0

#bug - 1764119 - rebalance status should display detailed info when any of the node is dowm
TEST kill_glusterd 2
EXPECT_WITHIN $REBALANCE_TIMEOUT "completed" rebalance_status_field_1 $V0

TEST start_glusterd 2
#bug-1245142

$CLI_1 volume rebalance $V0  start &
#kill glusterd2 after requst sent, so that call back is called
#with rpc->status fail ,so roughly 1sec delay is introduced to get this scenario.
sleep 1
kill_glusterd 2
#check glusterd commands are working after rebalance start command
EXPECT 'Started' cluster_volinfo_field 1 $V0 'Status';

cleanup;

