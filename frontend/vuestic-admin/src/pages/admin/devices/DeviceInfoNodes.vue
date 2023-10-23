<template>
    <div class="markup-tables flex">
        <OrbitSpinner v-if="nodeData.length == 0" />
        <va-card class="node-card" v-for="(node_data) in nodeData">
            <va-card-title>{{ node_data.name }}</va-card-title>
            <va-card-content>
                <div class="table-wrapper">
                    <table class="va-table va-table--striped va-table--hoverable">
                        <colgroup>
                            <col style="width:20%">
                            <col style="width:10%">
                            <col style="width:10%">
                            <col style="width:10%">
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
                            <tr v-for="(prop, prop_key) in node_data.properties">
                                <td>
                                    <VaPopover :message="getPropGlobalId(node_data, prop)"
                                        @click="copyGlobalId(node_data, prop)">
                                        {{ prop.name }}
                                    </VaPopover>
                                </td>
                                <td>{{ prop.value }}<span v-if="prop.unit"> [{{ prop.unit }}]</span></td>
                                <td>
                                    <VaPopover class="test" :message="getPropGlobalId(node_data, prop)">
                                        {{ formatting.formatTimestamp(prop.timestamp) }}
                                    </VaPopover>
                                </td>
                                <td>
                                    <div v-if="prop.settable">
                                        <boolean-setter v-if="dataTypes.isBooleanProperty(prop)" :device_id="device_id"
                                            :node_id="node_data.id" :prop_id="prop_key"
                                            :value="dataTypes.parseBooleanProperty(prop.value)" @changed="onChanged" />
                                        <span v-if="prop.datatype != 'boolean'"> TODO {{ prop.datatype }}</span>
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </va-card-content>
        </va-card>
    </div>
</template>

<style lang="scss">
.va-popover__content {
    position: relative;
    z-index: 1000;
}

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
import { defineComponent } from 'vue'
import deviceService from '../../../services/fairyNode/DeviceService'
import { DeviceNode, DeviceNodeProperty } from '../../../services/fairyNode/DeviceService'
import formatting from '../../../services/fairyNode/Formatting'
import dataTypes from '../../../services/fairyNode/DataTypes'
import { ref } from 'vue'
import { OrbitSpinner } from 'epic-spinners'

import BooleanSetter from "./setters/BooleanSetter.vue"
import { useToast } from 'vuestic-ui'

export default defineComponent({
    components: {
        OrbitSpinner,
        BooleanSetter,
    },
    props: {
        hardware_id: String,
        device_id: String,
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