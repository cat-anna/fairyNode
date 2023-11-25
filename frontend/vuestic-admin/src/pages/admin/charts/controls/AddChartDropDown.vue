<template>
  <va-dropdown trigger="hover" class="mr-2 mb-2" preset="primary" @open="updateData">
    <template #anchor>
      <va-button>
        <va-icon :name="'material-icons-add'" />
        {{ t('charts.add_chart') }}
      </va-button>
    </template>

    <va-dropdown-content>
      <busy-spinner v-if="seriesInfo.length == 0" />
      <va-scroll-container class="max-h-[400px]" vertical>
        <va-list>
          <va-list-item v-for="series in seriesInfo" :key="series.id" class="flex py-1">
            <va-button plain @click="$emit('AddChart', getChartDesc(series))">
              {{ series.name }}
            </va-button>
          </va-list-item>
        </va-list>
      </va-scroll-container>
    </va-dropdown-content>
  </va-dropdown>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { defineComponent } from 'vue'
  import { ChartSeries } from '../../../../services/fairyNode/PropertyService'
  import propertyService from '../../../../services/fairyNode/PropertyService'
  import { ChartDesc } from '../../../../stores/global-store'

  export default defineComponent({
    props: {},
    emits: ['AddChart'],
    setup() {
      const { t } = useI18n()
      return { t }
    },
    data() {
      return {
        seriesInfo: new Array<ChartSeries>(),
      }
    },
    methods: {
      getChartDesc(series: ChartSeries): ChartDesc {
        return {
          name: series.name || '',
          seriesId: series.series.map((e) => e.global_id),
        }
      },
      updateData() {
        if (this.seriesInfo.length > 0) {
          return
        }

        propertyService.chartSeries().then((data) => {
          var sortFunc = function (a: any, b: any) {
            var a_name = a.name || ''
            var b_name = b.name || ''
            return a_name.toLowerCase().localeCompare(b_name.toLowerCase())
          }

          if (data.groups) {
            data.groups.sort(sortFunc)
            this.seriesInfo = data.groups
          }
        })
      },
    },
  })
</script>

<style lang="scss"></style>
