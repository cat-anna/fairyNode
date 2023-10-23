<template>
    <div class="markup-tables flex">
        <OrbitSpinner v-if="nodeData.size == 0" />
        <va-card class="node-card" v-for="(node_data, key, index) in nodeData">
            <va-card-title>{{ key }}</va-card-title>
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
                                <th>Name</th>
                                <th>Value</th>
                                <th>Timestamp</th>
                                <th>Set</th>
                            </tr>
                        </thead>

                        <tbody>
                            <tr v-for="(prop, prop_key) in node_data.properties">
                                <td>{{ prop.name }}</td>
                                <td>{{ prop.value }}<span v-if="prop.unit"> [{{ prop.unit }}]</span></td>
                                <td>{{ formatting.formatTimestamp(prop.timestamp) }}</td>
                                <td>
                                    <div v-if="prop.settable">
                                        <boolean-setter
                                            v-if="prop.datatype == 'boolean'"
                                            :device_id="device_id"
                                            :node_id="key"
                                            :prop_id="prop_key"
                                            :value="dataTypes.parseBooleanProperty(prop.value)"
                                             />
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </va-card-content>
          <va-separator />
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
import dataTypes from '../../../services/fairyNode/DataTypes'
import { ref, watch } from 'vue'
import { OrbitSpinner } from 'epic-spinners'

import BooleanSetter from "./setters/BooleanSetter.vue"

export default defineComponent({
    components: {
        OrbitSpinner,
        BooleanSetter,
    },
    setup() {
        const route = useRoute()
        const device_id = ref(route.params.id as string)
        const nodeData = ref(new Map<string, DeviceNode>())

        watch(
            () => route.params.id,
            async newId => {
                device_id.value = newId as string
                // console.log(device_id)
                nodeData.value = new Map<string, DeviceNode>()
                nodeData.value = await deviceService.nodesSummary(device_id.value)
            }
        )
        const { t } = useI18n()
        return { t, device_id, nodeData, formatting  }
    },
    data() {
        return {
            timerId: 0,
            dataTypes: dataTypes,
        }
    },

    mounted() {
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
        async getData() {
            this.nodeData = await deviceService.nodesSummary(this.device_id)
        }
    }
})
</script>