package com.switch2go.aac.settings

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import com.switch2go.aac.FakeCategoriesUseCase
import com.switch2go.aac.MainDispatcherRule
import com.switch2go.aac.basetest.utils.FakeLocaleProvider
import com.switch2go.aac.presets.Category
import com.switch2go.aac.utils.FakeLocalizedResourceUtility
import com.switch2go.aac.utils.locale.LocalesWithText
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

@Deprecated("We should migrate this over to androidTest, as the Fake CategoriesUseCase is" +
        "getting too complex.")
class AddUpdateCategoryViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private val categoriesUseCase = FakeCategoriesUseCase()

    private fun createViewModel(): AddUpdateCategoryViewModel {
        return AddUpdateCategoryViewModel(
            categoriesUseCase,
            FakeLocalizedResourceUtility(),
            FakeLocaleProvider()
        )
    }

    @Test
    fun `stored category name updated`() = runTest {
        categoriesUseCase._categories.update {
            listOf(
                Category.StoredCategory(
                    categoryId = "1",
                    localizedName = LocalesWithText(mapOf("en_US" to "Category")),
                    hidden = false,
                    sortOrder = 0
                )
            )
        }

        val vm = createViewModel()

        vm.updateCategory("1", "New Category")

        assertEquals(
            listOf(
                Category.StoredCategory(
                    categoryId = "1",
                    localizedName = LocalesWithText(mapOf("en_US" to "New Category")),
                    hidden = false,
                    sortOrder = 0
                )
            ),
            categoriesUseCase.categories().first()
        )
    }

    @Test
    fun `category name updated does not wipe other locale`() = runTest {
        categoriesUseCase._categories.update {
            listOf(
                Category.StoredCategory(
                    categoryId = "1",
                    localizedName = LocalesWithText(mapOf("en_US" to "Category", "es_US" to "Spanish")),
                    hidden = false,
                    sortOrder = 0
                )
            )
        }

        val vm = createViewModel()

        vm.updateCategory("1", "New Category")

        assertEquals(
            listOf(
                Category.StoredCategory(
                    categoryId = "1",
                    localizedName = LocalesWithText(mapOf("en_US" to "New Category", "es_US" to "Spanish")),
                    hidden = false,
                    sortOrder = 0
                )
            ),
            categoriesUseCase.categories().first()
        )
    }

}