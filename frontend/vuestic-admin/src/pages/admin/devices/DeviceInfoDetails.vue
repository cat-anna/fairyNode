<template>
    <!-- <OrbitSpinner v-if="nodeData.length == 0" /> -->
    <!-- <va-card class="mb-2" v-for="(node_data) in nodeData">
        <va-card-title>{{ node_data.name }}</va-card-title>
        <va-card-content>
            <div class="table-wrapper">
                <table class="va-table va-table--striped va-table--hoverable">
                    <colgroup>
                        <col style="width:25%">
                        <col style="width:20%">
                        <col style="width:15%">
                        <col style="width:40%">
                    </colgroup>
                    <thead>
                        <tr>
                            <th> {{ t("deviceInfo.nodes.property.name") }} </th>
                            <th> {{ t("deviceInfo.nodes.property.value") }} </th>
                            <th> {{ t("deviceInfo.nodes.property.timestamp") }} </th>
                            <th> {{ t("deviceInfo.nodes.property.set") }} </th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="prop_data in node_data.properties">
                            <td>
                                <VaPopover :message="getPropGlobalId(node_data, prop_data)"
                                    @click="copyGlobalId(node_data, prop_data)">
                                    {{ prop_data.name }}
                                </VaPopover>
                            </td>
                            <td>{{ prop_data.value }}<span v-if="prop_data.unit"> [{{ prop_data.unit }}]</span></td>
                            <td>
                                <VaPopover :message="getPropGlobalId(node_data, prop_data)">
                                    {{ formatting.formatTimestamp(prop_data.timestamp) }}
                                </VaPopover>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </va-card-content>
    </va-card> -->

    <device-details-variables :device_id="device_id" />
</template>

<style lang="scss">
.table-wrapper {
    overflow: auto;
    table-layout: fixed;

    .va-table {
        width: 100%;
    }
}
</style>

<script lang="ts">
import { useI18n } from 'vue-i18n'
import { defineComponent, ref } from 'vue'
import { useToast } from 'vuestic-ui'
import deviceService from '../../../services/fairyNode/DeviceService'
import { DeviceNode, DeviceNodeProperty } from '../../../services/fairyNode/DeviceService'
import formatting from '../../../services/fairyNode/Formatting'
import dataTypes from '../../../services/fairyNode/DataTypes'
import { OrbitSpinner } from 'epic-spinners'

import DeviceDetailsVariables from './details/DeviceDetailsVariables.vue'

export default defineComponent({
    components: {
        OrbitSpinner,
        DeviceDetailsVariables,
    },
    props: {
        hardware_id: String,
        device_id: {
            type: String,
            required: true
        },
    },
    watch: {
        async device_id() {
            console.log("watch " + this.device_id)
            this.nodeData = new Array<DeviceNode>()
            this.getData()
        }
    },
    setup() {
        const { init, close, closeAll } = useToast()
        const nodeData = ref(new Array<DeviceNode>())
        const { t } = useI18n()
        return {
            t, nodeData, formatting,
            toastShow: init,
        }
    },
    data() {
        return {
            timerId: 0,
            dataTypes: dataTypes,
        }
    },

    mounted() {
        console.log("mounted " + this.device_id)
        if (this.timerId == 0) {
            this.timerId = window.setInterval(() => { this.getData() }, 10 * 1000)
        }
        this.getData()
    },
    unmounted() {
        if (this.timerId != 0) {
            window.clearInterval(this.timerId)
            this.timerId = 0
        }
    },
    methods: {
        copyGlobalId(node: DeviceNode, prop: DeviceNodeProperty) {
            var gid = this.getPropGlobalId(node, prop)
            navigator.clipboard.writeText(gid)
            this.toastShow(this.t("deviceInfo.nodes.copyToClipboard") + ": " + gid)
        },
        getPropGlobalId(node: DeviceNode, prop: DeviceNodeProperty): string {
            return prop.global_id
        },
        onChanged() {
            this.getData()
        },
        async getData() {
            if (this.device_id) {
                this.nodeData = await deviceService.nodesSummary(this.device_id)
                this.nodeData.sort(function (a, b) {
                    return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                })
            }
        }
    }
})
</script>