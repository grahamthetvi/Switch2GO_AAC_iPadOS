package com.switch2go.aac.settings

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import com.switch2go.aac.FakeCategoriesUseCase
import com.switch2go.aac.MainDispatcherRule
import com.switch2go.aac.getOrAwaitValue
import com.switch2go.aac.presets.Category
import com.switch2go.aac.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class EditCategoryMenuViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private val categoriesUseCase = FakeCategoriesUseCase()

    private fun createViewModel(): EditCategoryMenuViewModel {
        return EditCategoryMenuViewModel(
            categoriesUseCase
        )
    }

    @Test
    fun `last category remaining true`() {
        categoriesUseCase._categories.update {
            listOf(
                Category.StoredCategory(
                    categoryId = "1",
                    localizedName = LocalesWithText(mapOf("en_US" to "category")),
                    hidden = false,
                    sortOrder = 0
                )
            )
        }

        val vm = createViewModel()
        vm.updateCategoryById("1")

        assertTrue(
            vm.lastCategoryRemaining.getOrAwaitValue()
        )
    }

    @Test
    fun `update hidden status updates`() = runTest {
        categoriesUseCase._categories.update {
            listOf(
                Category.StoredCategory(
                    categoryId = "1",
                    localizedName = LocalesWithText(mapOf("en_US" to "category")),
                    hidden = false,
                    sortOrder = 0
                )
            )
        }

        val vm = createViewModel()
        vm.updateCategoryById("1")
        vm.updateCategoryShown(false)

        assertTrue(
            categoriesUseCase.getCategoryById("1").hidden
        )
    }

}