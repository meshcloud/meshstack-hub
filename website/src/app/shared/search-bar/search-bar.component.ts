import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, ReactiveFormsModule } from '@angular/forms';

import { SearchService } from './search.service';

@Component({
  selector: 'mst-search-bar',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './search-bar.component.html',
  standalone: true
})
export class SearchBarComponent implements OnInit {
  public searchForm!: FormGroup;

  constructor(
    private fb: FormBuilder,
    private searchService: SearchService,
  ) { }

  public ngOnInit(): void {
    this.initializeSearchForm();
  }

  public onSearch(): void {
    const searchTerm = this.searchForm.value.searchTerm;
    this.searchService.setSearchTerm(searchTerm);
  }

  private initializeSearchForm(): void {
    this.searchForm = this.fb.group({
      searchTerm: ['']
    });
  }
}
