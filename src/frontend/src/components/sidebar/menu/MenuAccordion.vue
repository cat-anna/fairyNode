<template>
  <va-accordion v-model="accordionValue" class="sidebar-accordion va-sidebar__menu__inner" multiple>
    <va-collapse v-for="(route, idx) in items" :key="idx">
      <template #header>
        <va-sidebar-item :active="isRouteActive(route)" :to="route.children ? undefined : { name: route.name }">
          <va-sidebar-item-content>
            <va-icon :name="route.meta.icon" class="va-sidebar-item__icon" />

            <va-sidebar-item-title v-if="route.displayName">
              {{ t(route.displayName) }}
            </va-sidebar-item-title>
            <va-sidebar-item-title v-if="route.rawDisplayName">
              {{ route.rawDisplayName }}
            </va-sidebar-item-title>

            <va-icon v-if="route.children" :name="accordionValue[idx] ? 'expand_less' : 'expand_more'" />
          </va-sidebar-item-content>
        </va-sidebar-item>
      </template>
      <template v-for="(child, index) in route.children" :key="index">
        <va-sidebar-item :active="isRouteActive(child)" :to="{ name: child.name, params: child.params }">
          <va-sidebar-item-content>
            <div class="va-sidebar-item__icon"></div>

            <va-sidebar-item-title v-if="child.displayName">
              {{ t(child.displayName) }}
            </va-sidebar-item-title>
            <va-sidebar-item-title v-if="child.rawDisplayName">
              {{ child.rawDisplayName }}
            </va-sidebar-item-title>
          </va-sidebar-item-content>
        </va-sidebar-item>
      </template>
    </va-collapse>
  </va-accordion>
</template>

<script setup lang="ts">
  import { onMounted, ref } from 'vue'
  import { INavigationRoute } from '../NavigationRoutes'
  import { useRoute } from 'vue-router'
  import { useI18n } from 'vue-i18n'
  const { t } = useI18n()

  const props = withDefaults(
    defineProps<{
      items?: INavigationRoute[]
    }>(),
    {
      items: () => [],
    },
  )

  const accordionValue = ref<boolean[]>([])

  onMounted(() => {
    accordionValue.value = props.items.map((item) => isItemExpanded(item))
  })

  // function isGroup(item: INavigationRoute) {
  //   return !!item.children
  // }

  function isRouteActive(item: INavigationRoute) {
    return item.name === useRoute().name && JSON.stringify(item.params) === JSON.stringify(useRoute().params)
  }

  function isItemExpanded(item: INavigationRoute): boolean {
    if (!item.children) {
      return false
    }

    const isCurrentItemActive = isRouteActive(item)
    const isChildActive = !!item.children.find((child) => (child.children ? isItemExpanded(child) : isRouteActive(child)))

    return isCurrentItemActive || isChildActive
  }
</script>
