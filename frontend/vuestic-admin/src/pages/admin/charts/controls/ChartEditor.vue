<template>
  <va-card-title>
    <div>
      <va-input v-model="editedName" placeholder="Chart name" class="mr-3 grow-0 basis-24 text-sm" />
    </div>
    <div class="va-spacer"></div>

    <div>
      <va-popover placement="right" :disabled="true" class="px-2">
        <va-button plain @click="$emit('cancelEdit')">
          <va-icon name="material-icons-arrow_back" />
        </va-button>
      </va-popover>
      <va-popover placement="right" :disabled="true" class="px-2">
        <va-button plain @click="$emit('acceptEdit', getSelectedNodes(), editedName)">
          <va-icon name="material-icons-done" />
        </va-button>
      </va-popover>
    </div>
  </va-card-title>
  <va-card-content>
    <div class="edit_content rounded-3xl border p-4">
      <div class="flex items-center mb-2">
        <va-input v-model="filter" placeholder="Filter..." clearable class="mr-3 grow-0 basis-24" />
      </div>
      <va-scroll-container class="py-3" vertical>
        <va-tree-view v-model:checked="selectedNodes" class="series_tree_view" :expanded="expanded" :nodes="nodes" :filter="filter" selectable />
      </va-scroll-container>
    </div>
  </va-card-content>
</template>

<script lang="ts">
  import { useI18n } from 'vue-i18n'
  import { PropType, defineComponent, ref } from 'vue'

  import { TreeNode } from 'vuestic-ui'

  import propertyService from '../../../../services/fairyNode/PropertyService'
  import { ChartSeries, ChartSeriesListEntry } from '../../../../services/fairyNode/PropertyService'

  export default defineComponent({
    components: {},
    props: {
      name: {
        required: true,
        type: String,
      },
      seriesId: {
        required: true,
        type: Array as PropType<Array<string>>,
      },
    },
    emits: ['acceptEdit', 'cancelEdit'],
    setup() {
      const { t } = useI18n()
      const nodes = ref(new Array<TreeNode>())
      const selectedNodes = ref(new Array<string>())
      const editedName = ref('')
      return { t, nodes, selectedNodes, editedName }
    },
    data() {
      return {
        filter: '',
        expanded: [],
        generatedId: 0,
      }
    },
    mounted() {
      this.selectedNodes = this.seriesId
      this.editedName = this.name

      propertyService.chartSeries().then((data) => {
        var sortFunc = function (a: any, b: any) {
          var a_name = a.name || ''
          var b_name = b.name || ''
          return a_name.toLowerCase().localeCompare(b_name.toLowerCase())
        }

        // if (data.device) data.device.sort(sortFunc)
        // if (data.groups) data.groups.sort(sortFunc)
        if (data.groups) {
          data.groups.sort(sortFunc)
          this.addRootNode(data.groups)
        }
      })
    },
    methods: {
      nextId() {
        this.generatedId = this.generatedId + 1
        return this.generatedId
      },
      getSelectedNodes() {
        return this.selectedNodes.filter((e) => !e.startsWith('#'))
      },
      addRootNode(list: ChartSeries[]) {
        list.forEach((item) => {
          var children = this.addSeriesChildren(item.series)
          this.nodes.push({
            id: '#' + this.nextId(),
            label: item.name || item.unit || '?',
            children: children,
          })
        })

        // console.log(this.nodes)
      },
      addSeriesChildren(unitEntry: ChartSeriesListEntry[]): TreeNode[] {
        var children: TreeNode[] = []

        unitEntry.forEach((series) => {
          children.push({
            id: series.global_id,
            label: series.display_name,
          })
        })

        return children
      },
    },
  })
</script>

<style lang="scss">
  .edit_content {
    border-color: var(--va-background-border);
    min-height: 30vh;
    // height: 50vh;
  }
  .series_tree_view {
    max-height: 40vh;
  }
</style>
