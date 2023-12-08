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
                <th v-for="(item, index) in statsTable.header" :key="index">{{ item }}</th>
              </tr>
            </thead>

            <tbody>
              <tr v-for="(row, row_index) in statsTable.data" :key="row_index">
                <td v-for="(col, col_index) in row" :key="col_index">
                  <span v-if="isTimestamp(col_index)"> {{ formatting.formatTimestamp(col as number) }} </span>
                  <span v-else> {{ col }} </span>
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
  import formatting from '../../../../services/fairyNode/Formatting'
  import { StatsTable } from '../../../../services/fairyNode/StatusService'

  export declare type OptionalStatsTable = StatsTable | undefined

  export default defineComponent({
    props: {
      tableId: { type: String, required: true },
      moduleId: { type: String, required: true },
    },
    setup() {
      const statsTable: Ref<OptionalStatsTable> = ref()
      const { t } = useI18n()
      return {
        t,
        statsTable,
        formatting,
      }
    },
    data() {
      return {
        timerId: 0,
        title: '',
        visible: false,
        timestamps: new Set(),
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
        this.title = this.moduleId || this.tableId
      },
      async getData() {
        if ((this.visible || this.statsTable == null) && this.tableId) {
          this.statsTable = await statusService.getStatusTable(this.tableId)
          this.updateTitle()
          this.timestamps = new Set()
          for (let i = 0; i < this.statsTable.header.length; i++) {
            const header: string = this.statsTable.header[i]
            if (header.toLowerCase().endsWith('timestamp')) {
              this.timestamps.add(i)
            }
          }
        }
      },
      isTimestamp(index: number): boolean {
        return this.timestamps.has(index)
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
