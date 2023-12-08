<template>
  <busy-spinner v-if="deviceNodeData.length == 0" />
  <va-card v-for="nodeData in deviceNodeData" :key="nodeData.global_id" class="mb-2">
    <va-card-title>{{ nodeData.name }}</va-card-title>
    <va-card-content>
      <div class="table-wrapper">
        <table class="va-table va-table--striped va-table--hoverable">
          <colgroup>
            <col style="width: 25%" />
            <col style="width: 20%" />
            <col style="width: 20%" />
            <col style="width: 40%" />
          </colgroup>
          <thead>
            <tr>
              <th>{{ t('deviceInfo.nodes.property.name') }}</th>
              <th>{{ t('deviceInfo.nodes.property.value') }}</th>
              <th>{{ t('deviceInfo.nodes.property.timestamp') }}</th>
              <th>{{ t('deviceInfo.nodes.property.set') }}</th>
            </tr>
          </thead>

          <tbody>
            <tr v-for="propData in nodeData.properties" :key="propData.global_id">
              <td>
                <VaPopover :message="getPropGlobalId(nodeData, propData)" @click="copyGlobalId(nodeData, propData)">
                  {{ propData.name }}
                </VaPopover>
              </td>
              <td>
                {{ propData.value }}
                <span v-if="propData.unit"> [{{ propData.unit }}]</span>
              </td>
              <td>
                <VaPopover :message="getPropGlobalId(nodeData, propData)">
                  {{ formatting.formatTimestamp(propData.timestamp) }}
                </VaPopover>
              </td>
              <td>
                <div v-if="propData.settable">
                  <boolean-setter
                    v-if="dataTypes.isBooleanProperty(propData)"
                    :device-id="deviceId"
                    :node-id="nodeData.id"
                    :prop-id="propData.id"
                    :value="dataTypes.parseBooleanProperty(propData.value)"
                    @changed="onChanged"
                  />
                  <numeric-setter
                    v-else-if="dataTypes.isNumberProperty(propData)"
                    :device-id="deviceId"
                    :node-id="nodeData.id"
                    :prop-id="propData.id"
                    :value="dataTypes.parseNumberProperty(propData.value)"
                    @changed="onChanged"
                  />
                  <string-setter
                    v-else-if="dataTypes.isStringProperty(propData)"
                    :device-id="deviceId"
                    :node-id="nodeData.id"
                    :prop-id="propData.id"
                    :value="propData.value"
                    @changed="onChanged"
                  />
                  <integer-setter
                    v-else-if="dataTypes.isIntegerProperty(propData)"
                    :device-id="deviceId"
                    :node-id="nodeData.id"
                    :prop-id="propData.id"
                    :value="dataTypes.parseIntegerProperty(propData.value)"
                    @changed="onChanged"
                  />
                  <span v-else> TODO {{ propData.datatype }}</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </va-card-content>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref } from 'vue'
  import { useToast } from 'vuestic-ui'
  import deviceService from '../../../services/fairyNode/DeviceService'
  import { DeviceNode, DeviceNodeProperty } from '../../../services/fairyNode/DeviceService'
  import formatting from '../../../services/fairyNode/Formatting'
  import dataTypes from '../../../services/fairyNode/DataTypes'

  import BooleanSetter from './setters/BooleanSetter.vue'
  import NumericSetter from './setters/NumericSetter.vue'
  import StringSetter from './setters/StringSetter.vue'
  import IntegerSetter from './setters/IntegerSetter.vue'

  export default defineComponent({
    components: {
      BooleanSetter,
      NumericSetter,
      StringSetter,
      IntegerSetter,
    },
    props: {
      deviceId: { type: String, required: true },
    },
    setup() {
      const { init } = useToast()
      const deviceNodeData = ref(new Array<DeviceNode>())
      const { t } = useI18n()
      return {
        t,
        deviceNodeData,
        formatting,
        toastShow: init,
      }
    },
    data() {
      return {
        timerId: 0,
        dataTypes: dataTypes,
      }
    },
    watch: {
      async deviceId() {
        this.deviceNodeData = new Array<DeviceNode>()
        this.getData()
      },
    },

    mounted() {
      if (this.timerId == 0) {
        this.timerId = window.setInterval(() => {
          this.getData()
        }, 10 * 1000)
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
        this.toastShow(this.t('deviceInfo.nodes.copyToClipboard') + ': ' + gid)
      },
      getPropGlobalId(node: DeviceNode, prop: DeviceNodeProperty): string {
        return prop.global_id
      },
      onChanged() {
        this.getData()
      },
      async getData() {
        if (this.deviceId) {
          this.deviceNodeData = await deviceService.nodesSummary(this.deviceId)
          this.deviceNodeData.sort(function (a, b) {
            return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
          })
        }
      },
    },
  })
</script>

<style lang="scss">
  .table-wrapper {
    overflow: auto;
    table-layout: fixed;

    .va-table {
      width: 100%;
    }
  }
</style>
