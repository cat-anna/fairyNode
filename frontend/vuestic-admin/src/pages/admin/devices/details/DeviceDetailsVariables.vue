<template>
  <va-card class="mb-2">
    <va-card-title>{{ t('deviceInfo.details.variables.title') }}</va-card-title>
    <va-card-content>
      <OrbitSpinner v-if="pending" />
      <span v-if="!valid"> {{ t('deviceInfo.details.variables.invalid') }}</span>
      <div v-if="variablesData != null" class="table-wrapper">
        <table class="va-table va-table--striped va-table--hoverable">
          <colgroup>
            <col style="width: 30%" />
            <col style="width: 70%" />
          </colgroup>
          <thead>
            <tr>
              <th>{{ t('deviceInfo.details.variables.key') }}</th>
              <th>{{ t('deviceInfo.details.variables.value') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="varData in variablesData" :key="varData.key">
              <td>{{ varData.key }}</td>
              <td>{{ varData.value }}</td>
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
  import deviceService from '../../../../services/fairyNode/DeviceService'
  import { DeviceVariable } from '../../../../services/fairyNode/DeviceService'
  import dataTypes from '../../../../services/fairyNode/DataTypes'
  import { OrbitSpinner } from 'epic-spinners'

  export declare type OptionalVariablesData = null | DeviceVariable[]

  export default defineComponent({
    components: {
      OrbitSpinner,
    },
    props: {
      deviceId: {
        type: String,
        required: true,
      },
    },
    setup() {
      const variablesData = ref(<OptionalVariablesData>{})
      const { t } = useI18n()
      return {
        t,
        variablesData,
      }
    },
    data() {
      return {
        dataTypes: dataTypes,
        pending: true,
        valid: true,
      }
    },
    watch: {
      async deviceId() {
        this.variablesData = null
        this.getData()
      },
    },

    mounted() {
      this.getData()
    },
    // unmounted() {},
    methods: {
      onChanged() {
        this.getData()
      },
      async getData() {
        this.pending = true
        deviceService
          .variables(this.deviceId)
          .then((data) => {
            this.valid = true
            this.variablesData = data
            this.variablesData.sort(function (a, b) {
              return a.key.toLowerCase().localeCompare(b.key.toLowerCase())
            })
          })
          .catch((error) => {
            this.variablesData = null
            if (error.status == 400) {
              this.valid = false
            } else {
              //TODO
            }
          })
          .finally(() => {
            this.pending = false
          })
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
