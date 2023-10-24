<template>
    <div class="markup-tables flex">
        <OrbitSpinner v-if="nodeData.length == 0" />
        <va-card class="node-card" v-for="(node_data) in nodeData">
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
                                <td>
                                    <div v-if="prop_data.settable">
                                        <boolean-setter v-if="dataTypes.isBooleanProperty(prop_data)" :device_id="device_id"
                                            :node_id="node_data.id" :prop_id="prop_data.id"
                                            :value="dataTypes.parseBooleanProperty(prop_data.value)" @changed="onChanged" />
                                        <numeric-setter v-else-if="dataTypes.isNumberProperty(prop_data)" :device_id="device_id"
                                            :node_id="node_data.id" :prop_id="prop_data.id"
                                            :value="dataTypes.parseNumberProperty(prop_data.value)" @changed="onChanged" />
                                        <string-setter v-else-if="dataTypes.isStringProperty(prop_data)" :device_id="device_id"
                                            :node_id="node_data.id" :prop_id="prop_data.id"
                                            :value="prop_data.value" @changed="onChanged" />
                                        <integer-setter v-else-if="dataTypes.isIntegerProperty(prop_data)" :device_id="device_id"
                                            :node_id="node_data.id" :prop_id="prop_data.id"
                                            :value="dataTypes.parseIntegerProperty(prop_data.value)" @changed="onChanged" />
                                        <span v-else=""> TODO {{ prop_data.datatype }}</span>
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
import { defineComponent, ref } from 'vue'
import { useToast } from 'vuestic-ui'
import deviceService from '../../../services/fairyNode/DeviceService'
import { DeviceNode, DeviceNodeProperty } from '../../../services/fairyNode/DeviceService'
import formatting from '../../../services/fairyNode/Formatting'
import dataTypes from '../../../services/fairyNode/DataTypes'
import { OrbitSpinner } from 'epic-spinners'

import BooleanSetter from "./setters/BooleanSetter.vue"
import NumericSetter from "./setters/NumericSetter.vue"
import StringSetter from "./setters/StringSetter.vue"
import IntegerSetter from "./setters/IntegerSetter.vue"

export default defineComponent({
    components: {
        OrbitSpinner,
        BooleanSetter,
        NumericSetter,
        StringSetter,
        IntegerSetter,
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