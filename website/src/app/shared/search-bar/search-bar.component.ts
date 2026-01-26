import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { NavigationEnd, Router } from '@angular/router';
import { Subscription, debounceTime, distinctUntilChanged } from 'rxjs';

@Component({
  selector: 'mst-search-bar',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './search-bar.component.html',
  styleUrl: './search-bar.component.scss',
  standalone: true
})
export class SearchBarComponent implements OnInit, OnDestroy {
  public searchForm!: FormGroup;

  private routerSubscription!: Subscription;
  private searchSubscription!: Subscription;

  constructor(
    private router: Router,
    private fb: FormBuilder
  ) { }

  public ngOnInit(): void {
    this.initializeSearchForm();
    this.setupLiveSearch();
    this.setupRouterSubscription();
  }

  public ngOnDestroy(): void {
    this.routerSubscription?.unsubscribe();
    this.searchSubscription?.unsubscribe();
  }

  public onSearch(): void {
    const searchTerm = this.searchForm.value.searchTerm?.trim();
    this.performSearch(searchTerm);
  }

  private initializeSearchForm(): void {
    this.searchForm = this.fb.group({
      searchTerm: ['']
    });
  }

  private setupLiveSearch(): void {
    // Live search with debounce - searches as user types
    this.searchSubscription = this.searchForm.get('searchTerm')!.valueChanges
      .pipe(
        debounceTime(300), // Wait 300ms after user stops typing
        distinctUntilChanged() // Only emit when value actually changes
      )
      .subscribe(searchTerm => {
        this.performSearch(searchTerm?.trim());
      });
  }

  private setupRouterSubscription(): void {
    // Subscribe to route changes to update search term from query params
    this.routerSubscription = this.router.events.subscribe(event => {
      if (event instanceof NavigationEnd) {
        // Only clear search if we're not on /all and there's no searchTerm in URL
        const currentUrl = this.router.url;
        const hasSearchParam = currentUrl.includes('searchTerm=');

        if (!currentUrl.startsWith('/all') && !hasSearchParam) {
          // Clear the search form when navigating away from search results
          this.searchForm.patchValue({ searchTerm: '' }, { emitEvent: false });
        }
      }
    });
  }

  private performSearch(searchTerm: string): void {
    if (searchTerm) {
      this.router.navigate(['/'], {
        queryParams: { searchTerm }
      });
    } else {
      // Navigate to home without search params when search is cleared
      this.router.navigate(['/']);
    }
  }
}
