import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';
import { NavigationEnd, Router } from '@angular/router';
import { Subscription } from 'rxjs';

@Component({
  selector: 'mst-search-bar',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './search-bar.component.html',
  standalone: true
})
export class SearchBarComponent implements OnInit, OnDestroy {
  public searchForm!: FormGroup;

  private routerSubscription!: Subscription;

  constructor(
    private router: Router,
    private fb: FormBuilder
  ) { }

  public ngOnInit(): void {
    this.initializeSearchForm();
    this.routerSubscription = this.router.events.subscribe(event => {
      if (event instanceof NavigationEnd) {
        if (!this.router.url.startsWith('/all')) {
          this.searchForm.reset();
        }
      }
    });
  }

  public ngOnDestroy(): void {
    this.routerSubscription.unsubscribe();
  }

  public onSearch(): void {
    const searchTerm = this.searchForm.value.searchTerm;
    this.router.navigate(['/all'], {
      queryParams: { searchTerm }
    });
  }

  private initializeSearchForm(): void {
    this.searchForm = this.fb.group({
      searchTerm: ['']
    });
  }
}
