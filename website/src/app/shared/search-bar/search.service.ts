import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class SearchService {

  private searchTermSubject = new BehaviorSubject<string>('');

  public getSearchTerm$(): Observable<string> {
    return this.searchTermSubject.asObservable();
  }

  constructor() { }

  public setSearchTerm(term: string): void {
    this.searchTermSubject.next(term);
  }

  public clearSearchTerm(): void {
    this.searchTermSubject.next('');
  }
}