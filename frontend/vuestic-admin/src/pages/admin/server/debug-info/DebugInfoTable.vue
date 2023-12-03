<template>
  <va-card class="mb-2">
    <va-collapse v-model="visible" class="min-w-96" :header="title" icon="material-icons-receipt">
      <!-- <va-card-title v-if="statsTable != null">
      title
    </va-card-title> -->
      <va-card-content>
        <busy-spinner v-if="statsTable == null" />
        <div v-else class="table-wrapper">
          <table class="va-table va-table--striped va-table--hoverable">
            <thead>
              <tr>
                <th v-for="item in statsTable.header" :key="item">{{ item }}</th>
              </tr>
            </thead>

            <tbody>
              <tr v-for="(row, index) in statsTable.data" :key="index">
                <td v-for="field in row" :key="field">
                  {{ field }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </va-card-content>
    </va-collapse>
  </va-card>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent, ref, Ref } from 'vue'
  import statusService from '../../../../services/fairyNode/StatusService'
  import { StatsTable } from '../../../../services/fairyNode/StatusService'

  export declare type OptionalStatsTable = StatsTable | undefined

  export default defineComponent({
    props: {
      tableId: { type: String, required: true },
    },
    setup() {
      const statsTable: Ref<OptionalStatsTable> = ref()
      const { t } = useI18n()
      return {
        t,
        statsTable,
      }
    },
    data() {
      return {
        timerId: 0,
        title: '',
        visible: false,
      }
    },
    watch: {
      async tableId() {
        this.statsTable = null
        this.getData()
      },
      async visible() {
        this.getData()
        if (this.visible) {
          this.subscribe()
        } else {
          this.clearSubscription()
        }
      },
    },

    mounted() {
      this.getData()
    },
    // unmounted() { },
    methods: {
      subscribe() {
        if (this.timerId == 0) {
          this.timerId = window.setInterval(() => {
            this.getData()
          }, 10 * 1000)
        }
      },
      clearSubscription() {
        if (this.timerId != 0) {
          window.clearInterval(this.timerId)
          this.timerId = 0
        }
      },
      updateTitle() {
        if (this.statsTable) {
          this.title = this.statsTable.title || this.tableId
          if (this.statsTable.tag) {
            this.title += ' [' + this.statsTable.tag + ']'
          }
          return
        }

        if (this.tableId) {
          this.title = this.tableId
          return
        }

        this.title = ''
      },
      async getData() {
        if ((this.visible || this.statsTable == null) && this.tableId) {
          this.statsTable = await statusService.getStatusTable(this.tableId)
          this.updateTitle()
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
