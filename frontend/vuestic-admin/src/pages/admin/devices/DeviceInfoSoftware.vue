<template>
    SOFTWARE
    <div class="markup-tables flex">
        <va-card class="node-card" v-for="(node_data, key, index) in nodeData">
            <va-card-title>{{ key }}</va-card-title>
            <va-card-content>
                <div class="table-wrapper">
                    <table class="va-table va-table--striped va-table--hoverable">
                        <colgroup>
                            <col style="width:40%">
                            <col style="width:20%">
                            <col style="width:20%">
                        </colgroup>
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Value</th>
                                <th>Timestamp</th>
                                <!-- <th>Uptime</th>  -->
                                <!-- <th>Country</th> -->
                            </tr>
                        </thead>

                        <tbody>
                            <tr v-for="(prop, prop_key) in node_data.properties">
                                <td>
                                    <!-- <router-link style="text-decoration: none; color: inherit;" -->
                                    <!-- :to="{ path: '/admin/devices/' + device.id, params: { id: device.id } }"> -->
                                    {{ prop.name }}
                                    <!-- </router-link> -->
                                </td>
                                <td>{{ prop.value }} {{ prop.unit }}</td>
                                <td> {{ formatting.formatTimestamp(prop.timestamp) }} </td>

                                <!-- <td><va-badge :text="device.status" :color="getStatusColor(device.status)" /></td> -->
                                <!-- <td><va-badge :text="device.errors" color="danger" v-if="device.errors > 0" /></td> -->
                                <!-- <td>{{ formatSeconds(device.uptime) }}</td> -->
                            </tr>
                        </tbody>
                    </table>
                </div>

            </va-card-content>
        </va-card>
    </div>
</template>

<style lang="scss">
.node-card {
    margin-bottom: 15px;
}
.markup-tables {
    .table-wrapper {
        overflow: auto;
        table-layout: fixed;
    }
    .va-table {
        width: 100%;
    }
}
</style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router';
import { defineComponent } from 'vue'
import deviceService from '../../../services/fairyNode/DeviceService'
import { DeviceNode, DeviceNodeProperty } from '../../../services/fairyNode/DeviceService'
import formatting from '../../../services/fairyNode/Formatting'
import { nextTick } from 'process';

export default defineComponent({
    setup() {
        const { t } = useI18n()
        return { t }
    },
    data() {
        return {
            formatting: formatting,
            device_id: "",
            timerId: 0,
            nodeData: new Map<string, DeviceNode>(),
        }
    },

    mounted() {
        this.device_id = useRoute().params.id as string
        if (this.timerId == 0) {
            this.timerId = window.setInterval(() => { this.getData() }, 5 * 1000)
        }
        this.getData()
    },
    unmounted() {
        if (this.timerId != 0) {
            window.clearInterval(this.timerId)
            this.timerId = 0
        }
    },
    beforeRouteUpdate(from, to, next) {
        // this.device_id = this.$route.params.id as string
        console.log("DeviceInfoSoftware beforeRouteUpdate")
        next()
    },

    methods: {
        getData() {
            this.device_id = this.$route.params.id as string
            // deviceService.nodesSummary(this.device_id).then(data => this.nodeData = data)
            // console.log(this.nodeData)
        }
    }
})
</script>